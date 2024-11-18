{ stackoverflow.com/questions/9620886/is-it-safe-to-set-the-boolean-value-in-thread-from-another-one
 IIRC Intel guarantees that a write to a single byte, or to a properly aligned 2- or 4-byte value,
 will always be an atomic write.
 }

unit Campaigns;

interface

uses
  Classes, Sysutils, System.Generics.Collections, Misc, DateUtils,
  SendSMS;

const
  SPLIT_CHAR = ';'; // e.g: 'Profile1;Profile2;' and 'Group1;Group2;'

type
  TUDContact = record
    ContactName: string;
    Phone: string;
  end;
  TUPContactsAr = array of TUDContact;


  TBaseCol = class
  public
    Name: string;
  end;

  TGroup = class(TBaseCol)
  public
    Contacts: TUPContactsAr; // temporary array, exists only while sending (to save memory)
    ContactsCount: integer;
  end;

  TSMSProfile = class(TBaseCol)
  public
    SMSText: string;
  end;


  TCampaign = class;
  TOnSentSMS = procedure (aCampaign: TCampaign; aProfile: TSMSProfile; aGroup: TGroup;
      const aContact: TUDContact; aResult: TSMSError) of object;

  TRepeatCase = (rcNone, rcMinutes, rcHours, rcDays, rcWeeks, rcMonths, rcYears);
  TCampaignAction = (caBeforeStart, caFinished, caSetAlarm);
  TOnCampaignAction = procedure (aAction: TCampaignAction; aCampaign: TCampaign; var aStop: boolean) of object;

  TCampaign = class(TBaseCol)
  strict private
    fOnSentSMS: TOnSentSMS;
    fOnCampAction: TOnCampaignAction;
    fStartDateTime: TDateTime;
    fStop: boolean;
    fSmsMan: TSMSSend;
    procedure SendSMSForGroup(aSMS: TSMSProfile; aGroup: TGroup);
    procedure SetStartDateTime(const Value: TDateTime);
    function FindInList<T:class>(aClass: TBaseCol; aList: TList<T>): integer;
    procedure SetNewStartDateRepeat;
  public
    Groups: TList<TGroup>;
    SMSProfiles: TList<TSMSProfile>;
    EndDateTime: TDateTime;
    Enable: boolean;
    Completed: boolean;
    RepeatCase: TRepeatCase;
    RepeatValue: integer;
    constructor Create(aOnSendProc: TOnSentSMS; aOnCampAction: TOnCampaignAction);
    destructor Destroy; override;
    procedure StartSendingThread;
    procedure StopSending;
    function IsExpired(aCurDateTime: TDateTime): boolean;
    function GetProfilesString: string;
    function GetGroupsString: string;
    function DeleteGroup(aGroup: TGroup): boolean;
    function DeleteProfile(aProfile: TSMSProfile): boolean;
    function CalcNextRepeatDate: TDateTime;
    procedure CheckAndSetDisabled(const aCurDateTime: TDateTime);
    property StartDateTime: TDateTime read fStartDateTime write SetStartDateTime;
  end;

  function CalculateNextRepeatDate(aStartDT: TDateTime; aRepeatCase: TRepeatCase;
    aRepeatValue: integer): TDateTime;

implementation

{ TCampaign }

constructor TCampaign.Create(aOnSendProc: TOnSentSMS; aOnCampAction: TOnCampaignAction);
begin
  Assert(Assigned(aOnSendProc));
  Groups := TList<TGroup>.Create;
  SMSProfiles := TList<TSMSProfile>.Create;
  fOnSentSMS := aOnSendProc;
  fOnCampAction := aOnCampAction;
end;

destructor TCampaign.Destroy;
begin
  Groups.Free;
  SMSProfiles.Free;
  inherited;
end;

// Only disable Campaign in special cases
procedure TCampaign.CheckAndSetDisabled(const aCurDateTime: TDateTime);
begin
  if Enable then
    Enable := not (IsExpired(aCurDateTime) or
                 Completed or
                 (Groups.Count = 0) or
                 (SMSProfiles.Count = 0)
                 );
end;

function TCampaign.GetGroupsString: string;
var
  i: Integer;
begin
  Result := '';
  for i := 0 to Groups.Count - 1 do
    Result := Result + Groups.List[i].Name + SPLIT_CHAR;
end;

function TCampaign.GetProfilesString: string;
var
  i: Integer;
begin
  Result := '';
  for i := 0 to SMSProfiles.Count - 1 do
    Result := Result + SMSProfiles.List[i].Name + SPLIT_CHAR;
end;

function TCampaign.IsExpired(aCurDateTime: TDateTime): boolean;
begin
  Result := (EndDateTime <> 0) and (aCurDateTime > EndDateTime);
end;

// calc new StartDate if Campaign can repeat
procedure TCampaign.SetNewStartDateRepeat;
var
  vNewStartDate: TDateTime;
begin
  if RepeatCase <> rcNone then
  begin
    vNewStartDate := CalcNextRepeatDate;
    if (EndDateTime <> 0) and (vNewStartDate > EndDateTime) then
    begin
      Completed := true;
      Enable := false;
      exit;
    end;

    StartDateTime := vNewStartDate;
    Completed := false;
  end;
end;

// data will be always in future, because of using Now + one interval.
function TCampaign.CalcNextRepeatDate: TDateTime;
var
  vNow: TDateTime;
begin
  vNow := Now;
  if StartDateTime > vNow then
    Result := StartDateTime
  else
  begin
    if RepeatCase = rcNone then
      Result := StartDateTime
    else
      Result := CalculateNextRepeatDate(StartDateTime, RepeatCase, RepeatValue);
  end;
end;

function CalculateNextRepeatDate(aStartDT: TDateTime; aRepeatCase: TRepeatCase;
    aRepeatValue: integer): TDateTime;
var
  vRepeatSec: integer;
  vSec: integer;
begin
  Assert(aRepeatCase <> rcNone);
  Result := 0;
  if aRepeatCase in [rcMinutes, rcHours, rcDays, rcWeeks] then
  begin
    case aRepeatCase of
      rcMinutes: vRepeatSec := aRepeatValue * SecsPerMin;
      rcHours: vRepeatSec := aRepeatValue * SecsPerHour;
      rcDays: vRepeatSec := aRepeatValue * SecsPerDay;
      rcWeeks: vRepeatSec := aRepeatValue * SecsPerDay * DaysPerWeek
      else
        vRepeatSec := 0;
    end;
    vSec := SecondsBetween(Now, aStartDT);
    vSec := ((vSec div vRepeatSec) + 1) * vRepeatSec;
    Result := IncSecond(aStartDT, vSec);
  end
  else
  if aRepeatCase in [rcMonths, rcYears]  then
  begin
    case aRepeatCase of
      rcMonths: Result := IncMonth(aStartDT, aRepeatValue);
      rcYears: Result := IncYear(aStartDT, aRepeatValue);
    end;
  end;
  Assert(Result <> 0);
end;

procedure TCampaign.StartSendingThread;
begin
  fStop := false;
  Assert(Enable);
  if Assigned(fOnCampAction) then
    fOnCampAction(caBeforeStart, Self, fStop);
  if fStop then
    exit;

  TThread.CreateAnonymousThread(procedure ()
  var
    i, j: Integer;
  begin
    if fSmsMan = nil then
      fSmsMan := TSMSSend.Create;
    try
      for i := 0 to SMSProfiles.Count - 1 do
      begin
        if fStop then break;
        for j := 0 to Groups.Count - 1 do
        begin
          SendSMSForGroup(SMSProfiles.List[i], Groups.List[j]);
          if fStop then break;
        end;
      end;

    finally
      FreeAndNil(fSmsMan);
    end;

    TThread.Queue(nil, procedure
      begin
        // Campaign is complete, so disable it
        if not fStop then
        begin
          if RepeatCase = rcNone then
          begin
            Completed := true;
            Enable := false;
          end
          else
            SetNewStartDateRepeat;
         end;

        if Assigned(fOnCampAction) then
          fOnCampAction(caFinished, Self, fStop);
      end);
  end).Start;
end;

procedure TCampaign.StopSending;
begin
  fStop := true;
  {Intel, Arm, write to a single byte, or to a properly aligned 2- or 4-byte value
   will always be an atomic write.}
end;

procedure TCampaign.SendSMSForGroup(aSMS: TSMSProfile; aGroup: TGroup);
var
  i: Integer;
begin
  for i := 0 to High(aGroup.Contacts) do
  begin
    if fStop then exit;

    fSmsMan.SendSMS(aSMS.SMSText, aGroup.Contacts[i].Phone);

    // general pause between SMS, One SMS is sending during ~2825 ms
    // Broadcast receiver fires from another thread, and change Result
    while (fSmsMan.Result = seNotUpdated) and fSmsMan.CanSleep do;
    // if time is out - then fSmsMan.Result will be changed in fSmsMan.CanSleep method to seTimeout

    // do not use Queue here - class can be free and then call this method with nuil fSmsMan
    TThread.Synchronize(nil, procedure
      begin
        fOnSentSMS(Self, aSMS, aGroup, aGroup.Contacts[i], fSmsMan.Result);

      end);
  end;
end;

procedure TCampaign.SetStartDateTime(const Value: TDateTime);
begin
  fStartDateTime := Value;
end;

function TCampaign.DeleteGroup(aGroup: TGroup): boolean;
var
  vIndex: integer;
begin
  vIndex := FindInList<TGroup>(aGroup, Groups);
  Result:= vIndex <> -1;
  if Result then
    Groups.Delete(vIndex);
end;

function TCampaign.DeleteProfile(aProfile: TSMSProfile): boolean;
var
  vIndex: integer;
begin
  vIndex := FindInList<TSMSProfile>(aProfile, SMSProfiles);
  Result:= vIndex <> -1;
  if Result then
    SMSProfiles.Delete(vIndex);
end;

function TCampaign.FindInList<T>(aClass: TBaseCol; aList: TList<T>): integer;
var
  i: Integer;
begin
  Result := -1;
  for i := 0 to aList.Count - 1 do
    if TBaseCol(aList.List[i]) = aClass then
    begin
      Result := i;
      break;
    end;
end;


end.
