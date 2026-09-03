import {NextResponse} from "next/server";
export const dynamic="force-dynamic";
export async function GET(){return NextResponse.json({ok:true,service:"APC Car Rental operations backend",location:"Panabo and Davao City",contact:"09478904510",timezone:process.env.APP_TIMEZONE||"Asia/Manila",currency:process.env.APP_CURRENCY||"PHP",policies:{reservationHoldMinutes:240,releaseWindow:"07:00-21:00",returnWindow:"07:00-21:00"}})}
