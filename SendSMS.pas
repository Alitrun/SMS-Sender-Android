unit SendSMS;

interface

uses
{$IFDEF ANDROID}
  Androidapi.JNI.GraphicsContentViewText, Androidapi.JNI.App, Androidapi.JNI.Telephony, Androidapi.Helpers,
  Androidapi.JNI.JavaTypes,
{$ENDIF}
  BroadcastReceiver, SysUtils;

type
  TSMSError = (seNotUpdated, seTimeout, seUnknown, seSent, seGenericFail, seNoService, seNullPDU, seRadioOff);

  TBaseSMSSend = class
  protected
    fResultTimeout: integer;
    fResult: TSMSError;
    procedure DoMyRelease; virtual;
  public
    procedure SendSMS(const aText, aPhone: string); virtual; abstract;
    function CanSleep: boolean; inline;
    property Result: TSMSError read fResult;
  end;

  {$IFDEF ANDROID}
  TAndroidSMS = class(TBaseSMSSend)
  strict private
    fRelease: integer;
    fBroadcast: TBroadcastReceiver;
    procedure OnReceiveBroadcast(aContext: JContext; aIntent: JIntent; aResultCode: integer);
  protected
    procedure DoMyRelease; override;
  public
    constructor Create;
    destructor Destroy; override;
    procedure SendSMS(const aText, aPhone: string); override;
  end;
  {$ENDIF}

  TSMSSend = class {$IF Defined(MSWINDOWS) or Defined(IOS)}(TBaseSMSSend){$ENDIF}
                   {$IFDEF ANDROID}(TAndroidSMS){$ENDIF}
  public
    procedure SendSMS(const aText, aPhone: string); override;
  end;

implementation

{$IFDEF ANDROID}
const
  SENT_ACTION = 'SENT';
  EXTRA_PHONE_PARAM = 'P'; // PutExtra name, where to save phone number
{$ENDIF}



{ TBaseSMSSend }
// sleep = true, timeout = false
function TBaseSMSSend.CanSleep: boolean;
const
  INTERVAL = 100; // ms
  TIMEOUT_SEC = 60 * 1000;
var
  vTimeisOut: boolean;
begin
  Sleep(INTERVAL);
  inc(fResultTimeout, INTERVAL);
  vTimeisOut := fResultTimeout >= TIMEOUT_SEC;
  Result := not vTimeisOut;
  if vTimeisOut then
  begin
    fResult := seTimeout;
    DoMyRelease; // only for Android, becase it's waiting for incoming intent
  end;
end;

procedure TBaseSMSSend.DoMyRelease;
begin
end;


{ TSMSSend }

procedure TSMSSend.SendSMS(const aText, aPhone: string);
begin
  inherited;
  {$IFDEF MSWINDOWS}
  fResult := seSent;
  {$ENDIF}
end;



{ TAndroidSMS }

{$IFDEF ANDROID}
constructor TAndroidSMS.Create;
begin
  inherited;
  fBroadcast := TBroadcastReceiver.Create(OnReceiveBroadcast);
  fBroadcast.AddActions([StringToJString(SENT_ACTION)]);
end;

destructor TAndroidSMS.Destroy;
begin
  while fRelease <> 0 do  // waiting for incoming Intent with SMS result
  begin
    sleep(5);
  end;
  fBroadcast.Free;
  inherited;
end;

procedure TAndroidSMS.SendSMS(const aText, aPhone: string);
var
  Intent: JIntent;
  PendingIntent: JPendingIntent;
  vSmsManager: JSmsManager;
begin
  fResultTimeout := 0;
  fResult := seNotUpdated;
  AtomicIncrement(fRelease);
  Intent := TJIntent.Create;
  Intent.setAction(StringToJString(SENT_ACTION));
 // Intent.putExtra( StringToJString(EXTRA_PHONE_PARAM), StringTojString(aPhone));

  PendingIntent := TJPendingIntent.JavaClass.getBroadcast(TAndroidHelper.Context, 0, Intent, 0);

  vSmsManager := TJSmsManager.JavaClass.getDefault;
  vSmsManager.sendTextMessage( StringToJString(aPhone), nil, StringToJString(aText), PendingIntent, nil);
end;

{ usually android call it from "UI thread" - it's not main Delphi thread
  do not Synchronize it with main thread in case if you're going to free TAndroidSMS from main Delphi thread,
  because destructor just hangs! Look above  }
procedure TAndroidSMS.OnReceiveBroadcast(aContext: JContext; aIntent: JIntent; aResultCode: integer);
begin
 // vAction := JStringToString(aIntent.getAction);
 // vNum := JStringToString(aIntent.getStringExtra( StringToJString(EXTRA_PHONE_PARAM) ) );

   // now change value, another thread is cheking periodically for this flag
    {Intel, Arm, write to a single byte, or to a properly aligned 2- or 4-byte value
     will always be an atomic write.}
  if aResultCode = TJActivity.JavaClass.RESULT_OK then
    fResult := seSent
  else if aResultCode = TJSmsManager.JavaClass.RESULT_ERROR_RADIO_OFF then
    fResult := seRadioOff
  else if aResultCode = TJSmsManager.JavaClass.RESULT_ERROR_GENERIC_FAILURE then
    fResult := seGenericFail
  else if aResultCode = TJSmsManager.JavaClass.RESULT_ERROR_NO_SERVICE then
    fResult := seNoService
  else if aResultCode = TJSmsManager.JavaClass.RESULT_ERROR_NULL_PDU then
    fResult := seNullPDU
  else fResult := seUnknown;

  AtomicDecrement(fRelease);
end;


procedure TAndroidSMS.DoMyRelease;
begin
  AtomicDecrement(fRelease);
end;
 {$ENDIF}

end.
