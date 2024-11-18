unit Scheduler;

interface

uses
  Classes, Campaigns, System.Generics.Collections, System.Generics.Defaults, SysUtils, Misc,
  SettingsFile;

type
  TOnSetAlarm = reference to procedure (aCampaign: TCampaign; aLastAlarmDT: TDateTime);
  TOnBeforeStartCampaign = reference to procedure (aActiveCampaign: TCampaign; var aContinue: boolean);
  TScheduler = class
  strict private
    fEnable: boolean;
    fSettings: TSettings;
    fGlobalCampaignsRef: TObjectList<TCampaign>; // Reference to Campaigns list in TCore
    fCampaigns: TList<TCampaign>;         // Enabled Campaigns and not expired
    fNearCampaign: TCampaign;
    fRecheckCampaigns: boolean;
    [weak]fOnSetAlarm: TOnSetAlarm;
    procedure LoadCampaignProfilesAndGroups(aCampaign: TCampaign);
    function FindNearestCampaignToStart: TCampaign;
    procedure SetupAlarmIfNeed(aCampaign: TCampaign);
  public
    constructor Create(aSettings: TSettings; aCampaignsRef: TObjectList<TCampaign>);
    destructor Destroy; override;
    procedure StartTimerThread;
    procedure Stop;
    procedure RecheckCampaigns;
    procedure StartSending;
    property OnSetAlarm: TOnSetAlarm read fOnSetAlarm write fOnSetAlarm;
  end;

implementation

{ TScheduler }



constructor TScheduler.Create(aSettings: TSettings; aCampaignsRef: TObjectList<TCampaign>);
begin
  fCampaigns := TList<TCampaign>.Create;
  fSettings := aSettings;
  fGlobalCampaignsRef := aCampaignsRef;
end;

destructor TScheduler.Destroy;
begin
  Stop;

  fGlobalCampaignsRef := nil;
  fSettings := nil;
  fCampaigns.Free;
  inherited;
end;

procedure TScheduler.StartTimerThread;
const
  TIMER_INTERVAL = 10 * 1000;
begin
  Assert(not fEnable);
  if fEnable then exit;

  fRecheckCampaigns := false;
  fEnable := true;
  fNearCampaign := FindNearestCampaignToStart;
  if fNearCampaign = nil then
  begin
    fEnable := false;
    exit;
  end;
  SetupAlarmIfNeed(fNearCampaign);

  TThread.CreateAnonymousThread(procedure ()
  begin
    TMonitor.Enter(Self); // using it only for Wait and Pulse functions
    try
      while fEnable do
      begin
        if Now >= fNearCampaign.StartDateTime then
        begin
          fEnable := false; // do not need synch here, cause boolean is always atomic on arm and x86/x64
          TThread.Queue(nil, procedure
          begin
            StartSending;
          end);
          exit;
        end
        else
          TMonitor.Wait(Self, TIMER_INTERVAL);

        if fRecheckCampaigns then
        begin
          fEnable := false;
          fRecheckCampaigns := false;
          TThread.Queue(nil, procedure
          begin
            StartTimerThread;
          end );
          exit;
        end;
      end;
    finally
      TMonitor.Exit(Self);
    end;
  end).Start;
end;

procedure TScheduler.Stop;
begin
  if fEnable = false then exit;

  fEnable := false;
  TMonitor.Pulse(Self);
 // fThread.WaitFor; //  can't use it because  FreeOnTerminate true - on finish it shows Handle invalid
end;

{Sort Campaigns by date and time, including repeat time, and get nearest.
 Main Thread }
function TScheduler.FindNearestCampaignToStart: TCampaign;
var
  vCurDateTime: TDateTime;
  i: Integer;
  vCampaign: TCampaign;
begin
  Result := nil;
  vCurDateTime := Now;
  fCampaigns.Clear;
  // select Enabled Campaigns and not expired and not completed
  for i := 0 to fGlobalCampaignsRef.Count - 1 do
  begin
    vCampaign := fGlobalCampaignsRef.List[i];
    vCampaign.CheckAndSetDisabled(vCurDateTime);
    if vCampaign.Enable then
      fCampaigns.Add(vCampaign);
  end;

  // sorting by date
  if fCampaigns.Count > 1 then
    fCampaigns.Sort( TComparer<TCampaign>.Construct(
         function (const L, R: TCampaign): integer
         begin
           if L.StartDateTime < R.StartDateTime then
             Result := -1
           else
             if L.StartDateTime > R.StartDateTime then
               Result := 1
             else
               Result := 0;
         end
     ));

   if fCampaigns.Count > 0 then
     Result := fCampaigns.List[0];
end;

// Starts in main thread
procedure TScheduler.StartSending;
begin
  Assert(fNearCampaign <> nil);
  if (fNearCampaign <> nil) then
  begin
    LoadCampaignProfilesAndGroups(fNearCampaign);
    fNearCampaign.StartSendingThread;
  end;
end;

{ Loads Profiles and Groups with all phones and names of current groups.
  Do it before start sending campaign.
  Usually we do not load this info for all campaigns, to save resources }
procedure TScheduler.LoadCampaignProfilesAndGroups(aCampaign: TCampaign);
var
  i: integer;
  vSMSProfile: TSMSProfile;
  vGroup: TGroup;
begin
  for i := 0 to aCampaign.SMSProfiles.Count - 1 do
  begin
    vSMSProfile := aCampaign.SMSProfiles.List[i];
    vSMSProfile.SMSText := fSettings.LoadSMSProfile(vSMSProfile.Name);
  end;

  for i := 0 to aCampaign.Groups.Count - 1 do
  begin
    vGroup := aCampaign.Groups.List[i];
    fSettings.LoadContactsOfGroup(vGroup.Name, vGroup.Contacts);
  end;
end;

{ Reread new campaigns list, and start shceduler if it is not started }
procedure TScheduler.RecheckCampaigns;
begin
  if fEnable then
  begin
    fRecheckCampaigns := true;
    TMonitor.Pulse(Self);
  end
  else
    StartTimerThread;
end;

// main tread
procedure TScheduler.SetupAlarmIfNeed(aCampaign: TCampaign);
var
  vNewDateTime: TDateTime;
begin
  vNewDateTime := aCampaign.StartDateTime;
  if vNewDateTime > Now then
  begin
    // check if Alarm already exists for this date
    if fSettings.LastSetAlarm = vNewDateTime then exit;

    // set new Alarm
    SetAlarmWakeUp(vNewDateTime);
    if Assigned(fOnSetAlarm) then
      fOnSetAlarm(aCampaign, vNewDateTime);
  end;
end;

end.
