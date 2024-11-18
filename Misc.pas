unit Misc;

interface

uses
{$IFDEF ANDROID}
  Androidapi.JNI.App, Androidapi.Helpers, Androidapi.JNI.JavaTypes,
  Androidapi.JNI.GraphicsContentViewText, FMX.Helpers.Android, Fmx.Platform.Android,
  Androidapi.JNI.Telephony, System.TimeSpan, Androidapi.JNI.Os, Androidapi.JNIBridge,
{$ENDIF}
  DateUtils, SysUtils, FMX.VirtualKeyboard, FMX.Platform, FMX.Types;

  procedure SetAlarmWakeUp(aDateTime: TDateTime);
  function StartedFromAlarmManager: boolean;
  procedure TurnOnAndKeepScreen(aEnable: boolean);
  procedure DimScreen(aEnable: boolean);
  function IsKeyboardVisible: boolean;

implementation


{Setup Android Alarm manager. Need to prepare java class and compile in to dex to receive it
http://stackoverflow.com/questions/42368123/how-to-pass-boolean-or-integer-to-intent-and-read-it-to-detect-that-my-activi}
{$IFDEF ANDROID}
procedure SetAlarmWakeUpAdnroid(aDateTime: TDateTime);

  function DateTimeLocalToUnixMSecGMT(const aDateTime: TDateTime): Int64;
  begin
    Result := DateTimeToUnix(aDateTime) * MSecsPerSec - Round(TTimeZone.Local.UtcOffset.TotalMilliseconds);
  end;

var
  Intent: JIntent;
  PendingIntent: JPendingIntent;
begin
  Intent := TJIntent.Create;
  Intent.setClassName(TAndroidHelper.Context, StringToJString('com.TestReceiver.AlarmReceiver'));
 // 'com.embarcadero.firemonkey.FMXNativeActivity'));
  // Оборачиваем Интент в PendingIntent
  PendingIntent := TJPendingIntent.JavaClass.getBroadcast(TAndroidHelper.Context, 1, Intent, 0);
  //getBroadcast(TAndroidHelper.Context, 1, Intent, 0);

  // Устанавливаем оповещение
  TAndroidHelper.AlarmManager.&set(TJAlarmManager.JavaClass.RTC_WAKEUP,
      DateTimeLocalToUnixMSecGMT(aDateTime), PendingIntent);
end;
 {$ENDIF}

procedure SetAlarmWakeUp(aDateTime: TDateTime);
begin
  {$IFDEF ANDROID}
  SetAlarmWakeUpAdnroid(aDateTime);
  {$ENDIF}
end;

function StartedFromAlarmManager: boolean;
begin
{$IFDEF ANDROID}
  Result := TAndroidHelper.Activity.getIntent.getBooleanExtra(StringToJString('StartedFromAM'), false);

  // this will work only if using Activity instead of Broadcast - TJPendingIntent.JavaClass.getActivity:
 //  Result := TAndroidHelper.Activity.getIntent.getIntExtra(TJIntent.JavaClass.EXTRA_ALARM_COUNT, 50);
{$ELSE}
  Result := false;
{$ENDIF}
end;

procedure TurnOnAndKeepScreen(aEnable: boolean);

  {$IFDEF ANDROID}
  procedure TurnOnAndKeepScreenAndroid(aEnable: boolean);
  var
    vFlags: integer;
  begin
    vFlags := TJWindowManager_LayoutParams.JavaClass.FLAG_TURN_SCREEN_ON or
        TJWindowManager_LayoutParams.JavaClass.FLAG_DISMISS_KEYGUARD or
        TJWindowManager_LayoutParams.JavaClass.FLAG_SHOW_WHEN_LOCKED or
        TJWindowManager_LayoutParams.JavaClass.FLAG_KEEP_SCREEN_ON;

    if aEnable then
    begin
      CallInUIThread (   // uses FMX.Helpers.Android
      procedure
      begin
        TAndroidHelper.Activity.getWindow.setFlags (vFlags, vFlags);
      end );
    end
    else
      CallInUIThread (
      procedure
      begin
        TAndroidHelper.Activity.getWindow.clearFlags (vFlags);
      end );
  end;
  {$ENDIF}

begin
{$IFDEF ANDROID}
  TurnOnAndKeepScreenAndroid(aEnable);
{$ELSE}

{$ENDIF}
end;

procedure DimScreen(aEnable: boolean);

  {$IFDEF ANDROID}
  procedure DimScreenAndroid(aEnable: boolean);
  var
    vWindow: JWindow;
    vWinParams: JWindowManager_LayoutParams;
  begin
    CallInUIThread (procedure
    begin
      vWindow := TAndroidHelper.Activity.getWindow;
      vWinParams := vWindow.getAttributes;
      if aEnable then
        vWinParams.screenBrightness := 0.1
      else
        vWinParams.screenBrightness := TJWindowManager_LayoutParams.JavaClass.BRIGHTNESS_OVERRIDE_NONE;
      // TJWindowManager_LayoutParams.JavaClass.BRIGHTNESS_OVERRIDE_OFF;
      // this will disable screen
      vWindow.setAttributes(vWinParams);
    end);
  end;
  {$ENDIF}

begin
{$IFDEF ANDROID}
  DimScreenAndroid(aEnable);
{$ELSE}

{$ENDIF}
end;

function IsKeyboardVisible: boolean;
var
  vService : IFMXVirtualKeyboardService;
begin
   TPlatformServices.Current.SupportsPlatformService(IFMXVirtualKeyboardService, IInterface(vService));
   Result := (vService <> nil) and (TVirtualKeyboardState.Visible in vService.VirtualKeyBoardState);
end;


// not used - moved to Java Broadcast Receiver
{$REGION 'Wake lock\ Android PowerManager' }
//uses Androidapi.JNI.Os, Androidapi.JNIBridge,
// About Partial lock with Java http://stackoverflow.com/questions/14741612/android-wake-up-and-unlock-device
// FUll lock with Delphi http://stackoverflow.com/questions/19021647/delphi-xe5-android-how-to-use-powermanager-wakelock
                          {
function GetPowerManager: JPowerManager;
var
  PowerServiceNative: JObject;
begin
  PowerServiceNative := TAndroidHelper.Context.getSystemService(TJContext.JavaClass.POWER_SERVICE);
  if not Assigned(PowerServiceNative) then
    raise Exception.Create('Could not locate Power Service');
  Result := TJPowerManager.Wrap((PowerServiceNative as ILocalObject).GetObjectID);
  if not Assigned(Result) then
    raise Exception.Create('Could not access Power Manager');
end;

var
  WakeLock: JPowerManager_WakeLock = nil;

function AcquireWakeLock: Boolean;
var
  PowerManager: JPowerManager;
begin
  Result := Assigned(WakeLock);
  if not Result then
  begin
    PowerManager := GetPowerManager;
    WakeLock := PowerManager.newWakeLock(TJPowerManager.JavaClass.SCREEN_BRIGHT_WAKE_LOCK or
    TJPowerManager.JavaClass.ACQUIRE_CAUSES_WAKEUP,
      StringToJString('Delphi'));
    Result := Assigned(WakeLock);
  end;
  if Result then
  begin
    if not WakeLock.isHeld then
    begin
      WakeLock.acquire;
      Result := WakeLock.isHeld
    end;
  end;
end;

procedure ReleaseWakeLock;
begin
  if Assigned(WakeLock) then
  begin
    WakeLock.release;
    WakeLock := nil
  end;
end;             }
{$ENDREGION}

end.
