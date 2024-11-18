package com.TestReceiver;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.os.PowerManager;
import android.os.Handler;

public class AlarmReceiver extends BroadcastReceiver {
    
    private static PowerManager.WakeLock mWakeLock;

    @Override
    public void onReceive(Context context, Intent intent) {
	 

     if (mWakeLock == null) {
       PowerManager pm = (PowerManager) context.getSystemService(Context.POWER_SERVICE);
       mWakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK | PowerManager.ACQUIRE_CAUSES_WAKEUP, "Delphi_SMS_Sender");
       mWakeLock.acquire();
      }
           
           Intent TestLauncher = new Intent();                        
            TestLauncher.setClassName(context, "com.embarcadero.firemonkey.FMXNativeActivity");
            TestLauncher.setFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP | Intent.FLAG_ACTIVITY_NEW_TASK); // I
            TestLauncher.putExtra("StartedFromAM", true);
            context.startActivity(TestLauncher);  
   //
	
    Handler h = new Handler();
    h.postDelayed(new Runnable(){
             public void run(){
            
       mWakeLock.release();  
       mWakeLock = null;       
       
             }
           }, 8000);
 //Toast.makeText(context, "Reelase! ("+mcounter.toString()+")", Toast.LENGTH_SHORT).show(); // For example	
    }
}
