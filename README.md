# APC Car Rental Operations System

Netlify-ready Next.js application prepared for the Supabase project created during setup.

## Before deployment

Configure the environment variables listed in `.env.example` in Netlify. Never commit a service-role key.

## Current application

The customer portal supports date-specific fleet availability, booking requests, four-hour reservation holds, private requirement uploads (one valid government ID plus a driver's license), and secure booking tracking.

The authenticated staff portal includes the live booking calendar and lifecycle, onsite settlement, editable approval-time pricing, voiding with audit history, vehicle release and return inspections, fleet/category rates, customers, documents, inspections and damage, finance, maintenance attention, reporting, activity logs, and settings.

Run the SQL files in `supabase/migrations` in Supabase before deploying matching frontend changes. Never commit a secret or service-role key.
