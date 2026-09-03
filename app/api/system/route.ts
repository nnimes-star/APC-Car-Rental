import {NextResponse} from "next/server";
export const dynamic="force-dynamic";
export async function GET(){return NextResponse.json({ok:true,service:"RoadReady Supabase backend",timezone:process.env.APP_TIMEZONE||"Asia/Manila",currency:process.env.APP_CURRENCY||"PHP",policies:{reservationHoldMinutes:240,releaseWindow:"07:00-21:00",returnWindow:"07:00-21:00"}})}
