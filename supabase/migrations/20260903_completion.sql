-- RoadReady completion migration
-- Safe to run more than once. Run once in Supabase SQL Editor before the final Netlify deploy.

create or replace function public.get_public_available_vehicles(
  p_pickup_at timestamptz,
  p_expected_return_at timestamptz
)
returns table (
  id uuid,
  manufacturer text,
  model_name text,
  variant text,
  category_name text,
  passenger_capacity integer,
  transmission text,
  rental_type text,
  daily_rate numeric,
  security_deposit numeric,
  overtime_rate numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if p_pickup_at is null or p_expected_return_at is null or p_expected_return_at <= p_pickup_at then
    raise exception 'A valid pickup and expected return schedule is required.';
  end if;
  if (p_pickup_at at time zone 'Asia/Manila')::time < time '07:00'
     or (p_pickup_at at time zone 'Asia/Manila')::time > time '21:00'
     or (p_expected_return_at at time zone 'Asia/Manila')::time < time '07:00'
     or (p_expected_return_at at time zone 'Asia/Manila')::time > time '21:00' then
    raise exception 'Scheduled release and return must be between 7:00 AM and 9:00 PM.';
  end if;

  return query
  select
    v.id,
    vm.manufacturer,
    vm.model_name,
    vm.variant,
    vc.name,
    coalesce(vm.passenger_capacity,vc.passenger_capacity),
    vm.transmission,
    coalesce(vm.rental_type,vc.default_rental_type),
    coalesce(v.daily_rate_override,vm.daily_rate_override,vc.daily_rate),
    coalesce(v.deposit_override,vm.deposit_override,vc.security_deposit),
    coalesce(v.overtime_rate_override,vm.overtime_rate_override,vc.overtime_rate)
  from vehicles v
  join vehicle_models vm on vm.id=v.model_id
  join vehicle_categories vc on vc.id=vm.category_id
  where v.status='ACTIVE'
    and v.operational_status not in ('MAINTENANCE','OUT_OF_SERVICE','RETIRED')
    and vm.status='ACTIVE' and vm.customer_visible=true
    and vc.status='ACTIVE' and vc.customer_visible=true
    and not exists (
      select 1 from vehicle_reservations vr
      where vr.vehicle_id=v.id and vr.active=true
        and vr.reserved_period && tstzrange(p_pickup_at,p_expected_return_at,'[)')
    )
  order by vc.display_order,vm.manufacturer,vm.model_name,v.unit_number;
end;
$$;

revoke all on function public.get_public_available_vehicles(timestamptz,timestamptz) from public;
grant execute on function public.get_public_available_vehicles(timestamptz,timestamptz) to anon,authenticated;

create or replace function public.track_public_booking(
  p_booking_reference text,
  p_mobile_number text
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare v_result jsonb;
begin
  select jsonb_build_object(
    'booking_reference',b.booking_reference,
    'booking_status',b.booking_status,
    'payment_status',b.payment_status,
    'pickup_at',b.pickup_at,
    'expected_return_at',b.expected_return_at,
    'reservation_expires_at',case when b.booking_status='RESERVED_AWAITING_SETTLEMENT' then b.reservation_expires_at else null end,
    'vehicle_name',concat_ws(' ',vm.manufacturer,vm.model_name,vm.variant),
    'customer_name',concat_ws(' ',c.first_name,c.last_name)
  ) into v_result
  from bookings b
  join customers c on c.id=b.customer_id
  join vehicles v on v.id=b.vehicle_id
  join vehicle_models vm on vm.id=v.model_id
  where upper(b.booking_reference)=upper(trim(p_booking_reference))
    and regexp_replace(c.mobile_number,'[^0-9]','','g')=regexp_replace(p_mobile_number,'[^0-9]','','g')
  limit 1;
  if v_result is null then raise exception 'Booking reference and mobile number did not match.'; end if;
  return v_result;
end;
$$;

revoke all on function public.track_public_booking(text,text) from public;
grant execute on function public.track_public_booking(text,text) to anon,authenticated;

-- Helpful indexes for the live operations screens.
create index if not exists bookings_pickup_at_idx on bookings(pickup_at desc);
create index if not exists bookings_expected_return_at_idx on bookings(expected_return_at desc);
create index if not exists bookings_status_idx on bookings(booking_status);
create index if not exists audit_logs_created_at_idx on audit_logs(created_at desc);
create index if not exists financial_transactions_created_at_idx on financial_transactions(created_at desc);
create index if not exists vehicle_inspections_created_at_idx on vehicle_inspections(created_at desc);
