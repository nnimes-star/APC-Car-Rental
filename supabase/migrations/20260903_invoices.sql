-- Permanent, printable final invoices. Safe to run more than once.

create table if not exists public.invoices (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null unique references public.bookings(id),
  invoice_number text not null unique,
  invoice_status text not null default 'ISSUED' check (invoice_status in ('DRAFT','ISSUED','VOIDED')),
  snapshot jsonb not null,
  issued_by uuid not null references auth.users(id),
  issued_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.invoices enable row level security;
drop policy if exists "Staff can view invoices" on public.invoices;
create policy "Staff can view invoices" on public.invoices for select to authenticated
using (exists(select 1 from public.staff_profiles sp where sp.id=auth.uid() and sp.active=true));

create index if not exists invoices_issued_at_idx on public.invoices(issued_at desc);

create or replace function public.admin_generate_invoice(p_booking_id uuid)
returns jsonb
language plpgsql
security definer
set search_path=public,pg_temp
as $$
declare
  v_actor uuid:=auth.uid();
  v_status text;
  v_invoice_number text;
  v_snapshot jsonb;
  v_charges jsonb;
  v_payments jsonb;
  v_charge_total numeric:=0;
  v_base_total numeric:=0;
  v_paid_total numeric:=0;
begin
  if v_actor is null or not exists(select 1 from staff_profiles where id=v_actor and active=true) then
    raise exception 'Authorized staff access required.';
  end if;

  select booking_status into v_status from bookings where id=p_booking_id for update;
  if not found then raise exception 'Booking not found.'; end if;
  if v_status not in ('PAYMENT_SETTLEMENT','COMPLETED') then
    raise exception 'A final invoice is available only after the vehicle is returned.';
  end if;

  select coalesce((pricing_snapshot->>'rental_total')::numeric,estimated_total-required_deposit,0)
  into v_base_total from bookings where id=p_booking_id;

  select coalesce(jsonb_agg(jsonb_build_object(
    'type',transaction_type,'description',description,'quantity',quantity,
    'unit_rate',unit_rate,'amount',amount,'status',transaction_status
  ) order by created_at),'[]'::jsonb),
  coalesce(sum(case when transaction_status='POSTED' and transaction_type not in ('BASE_RENTAL','PAYMENT','DEPOSIT','REFUND','REVERSAL') then amount else 0 end),0)
  into v_charges,v_charge_total
  from financial_transactions where booking_id=p_booking_id;
  v_charges:=jsonb_build_array(jsonb_build_object('type','BASE_RENTAL','description','Base rental','quantity',1,'unit_rate',v_base_total,'amount',v_base_total,'status','POSTED'))||v_charges;
  v_charge_total:=v_base_total+v_charge_total;

  select coalesce(jsonb_agg(jsonb_build_object(
    'receipt_number',receipt_number,'method',payment_method,'amount',amount,
    'status',payment_status,'received_at',received_at
  ) order by received_at),'[]'::jsonb),
  coalesce(sum(case when payment_status='POSTED' then amount else 0 end),0)
  into v_payments,v_paid_total
  from payments where booking_id=p_booking_id;

  select jsonb_build_object(
    'booking_id',b.id,'booking_reference',b.booking_reference,
    'booking_status',b.booking_status,'payment_status',b.payment_status,
    'customer',jsonb_build_object('name',concat_ws(' ',c.first_name,c.middle_name,c.last_name,c.suffix),'mobile',c.mobile_number,'email',c.email,'address',c.complete_address),
    'vehicle',jsonb_build_object('name',concat_ws(' ',vm.manufacturer,vm.model_name,vm.variant),'plate_number',v.plate_number,'unit_number',v.unit_number),
    'schedule',jsonb_build_object('pickup_at',b.pickup_at,'expected_return_at',b.expected_return_at,'actual_release_at',b.actual_release_at,'actual_return_at',b.actual_return_at),
    'pricing_snapshot',b.pricing_snapshot,'estimated_total',b.estimated_total,'required_deposit',b.required_deposit,
    'charges',v_charges,'payments',v_payments,'charge_total',v_charge_total,'paid_total',v_paid_total,
    'balance_due',greatest(v_charge_total-v_paid_total,0),'possible_refund',greatest(v_paid_total-v_charge_total,0),
    'generated_at',now()
  ) into v_snapshot
  from bookings b join customers c on c.id=b.customer_id join vehicles v on v.id=b.vehicle_id join vehicle_models vm on vm.id=v.model_id
  where b.id=p_booking_id;

  select invoice_number into v_invoice_number from invoices where booking_id=p_booking_id;
  if v_invoice_number is null then
    v_invoice_number:='INV-'||to_char(now() at time zone 'Asia/Manila','YYYYMMDD')||'-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,8));
  end if;

  insert into invoices(booking_id,invoice_number,invoice_status,snapshot,issued_by,issued_at,updated_at)
  values(p_booking_id,v_invoice_number,'ISSUED',v_snapshot,v_actor,now(),now())
  on conflict(booking_id) do update set snapshot=excluded.snapshot,invoice_status='ISSUED',updated_at=now();

  insert into audit_logs(actor_id,actor_type,entity_type,entity_id,action,new_value)
  values(v_actor,'STAFF','INVOICE',p_booking_id,'INVOICE_GENERATED',jsonb_build_object('invoice_number',v_invoice_number,'charge_total',v_charge_total,'paid_total',v_paid_total));

  return v_snapshot||jsonb_build_object('invoice_number',v_invoice_number);
end;
$$;

revoke all on function public.admin_generate_invoice(uuid) from public;
grant execute on function public.admin_generate_invoice(uuid) to authenticated;
