unit Core;

interface

uses
  SysUtils, SettingsFile, Scheduler, Classes, Campaigns, System.Generics.Collections, FMX.AddressBook,
  SendSMS;

type
  TCore = class
  strict private
    fSettings: TSettings;
    fScheduler: TScheduler;
    fOnCampAction: TOnCampaignAction;
    fOnSentSMS: TOnSentSMS;
    procedure OnSMSSentTCampaign(aCampaign: TCampaign; aProfile: TSMSProfile; aGroup: TGroup;
      const aContact: TUDContact; aResult: TSMSError);
    procedure OnCampaignActionTCampaign(aAction: TCampaignAction; aCampaign: TCampaign; var aStop: boolean);
    function FindNameInList<T:class>(const aName: string; aList: TObjectList<T>): T;
  public
    Groups: TObjectList<TGroup>;
    SMSProfiles: TObjectList<TSMSProfile>;
    Campaigns: TObjectList<TCampaign>;
    constructor Create;
    destructor Destroy; override;
    function LoadContactsFromPhoneBook(aList: TList<TUDContact>): integer;
    function AddNewGroup(const aName: string; aContactsCount: integer): TGroup;
    function AddNewSMSProfile(const aName: string): TSMSProfile;
    function CreateAddNewCampaign(const aName: string): TCampaign;
    procedure UpdateProfilesAndGroups(aCampaign: TCampaign; const aProfiles, aGroups: string);
    procedure DeleteGroup(aGroup: TGroup);
    procedure DeleteSMSProfile(aProfile: TSMSProfile);
    procedure DeleteCampaign(aCampaign: TCampaign);
    function GenerateCampaignName: string;
    property Settings: TSettings read fSettings;
    property Scheduler: TScheduler read fScheduler;
    property OnCampaignAction: TOnCampaignAction read fOnCampAction write fOnCampAction;
    property OnSentSMS: TOnSentSMS read fOnSentSMS write fOnSentSMS;
  end;

implementation


{ TCore }

constructor TCore.Create;

  // loads campaigns from ini file, - prepare campaigns with groups and profiles (reference to global lists)
  procedure LoadCampaigns;
  var
    vList: TStringList;
    i: Integer;
    vCampaignName, vProfiles, vGroups: string;
    vCampaign: TCampaign;
    vStartDateTime: TDateTime;
  begin
    vList := TStringList.Create;
    Settings.LoadCampaignsNames(vList);
    try
      for i := 0 to vList.Count - 1 do
      begin
        vCampaignName := vList.Names[i];
        vCampaign := CreateAddNewCampaign(vCampaignName);
        vCampaign.Name := vCampaignName;

        Settings.LoadCampaign(vCampaign.Name,
              vProfiles,
              vGroups,
              vStartDateTime,
              vCampaign.EndDateTime,
              vCampaign.RepeatCase,
              vCampaign.RepeatValue,
              vCampaign.Enable,
              vCampaign.Completed);
        vCampaign.StartDateTime := vStartDateTime;
        UpdateProfilesAndGroups(vCampaign, vProfiles, vGroups);
      end;
    finally
      vList.Free;
    end;
  end;

begin
  Groups := TObjectList<TGroup>.Create;
  SMSProfiles := TObjectList<TSMSProfile>.Create;
  Campaigns := TObjectList<TCampaign>.Create;
  fSettings := TSettings.Create;
  fSettings.LoadAllFromIni(Groups, SMSProfiles);
  LoadCampaigns;
  fScheduler := TScheduler.Create(fSettings, Campaigns);
  // this is "weak" method to prevent memory leak
  // http://fire-monkey.ru/topic/3901-утечка-при-использовании-анонимного-метода-или-анонимные-методы-циклические-ссылки-и-arc/
  fScheduler.OnSetAlarm := procedure (aCampaign: TCampaign; aLastAlarmDT: TDateTime)
    var
      vDummy: boolean;
    begin
      Settings.LastSetAlarm := aLastAlarmDT;
    //  Settings.SaveSettings(aLastAlarmDT);
      if Assigned(fOnCampAction) then
        fOnCampAction(caSetAlarm, aCampaign, vDummy);

    end;
end;

destructor TCore.Destroy;

  procedure SaveCampaignsStatus;
  var
    i: Integer;
    vCamp: TCampaign;
  begin
    for i := 0 to Campaigns.Count - 1 do
    begin
      vCamp := Campaigns.List[i];
      Settings.SaveCampaignFlags(vCamp.Name, vCamp.Enable, vCamp.Completed, vCamp.StartDateTime);
    end;
    // will update ini file on fSettings destructor
  end;

begin
  fScheduler.Stop;
  Sleep(20); // waiting second thread
  SaveCampaignsStatus;

  fScheduler.DisposeOf;
  Groups.DisposeOf;
  SMSProfiles.DisposeOf;
  Campaigns.DisposeOf;
  fSettings.DisposeOf;
  inherited;
end;

function TCore.AddNewGroup(const aName: string; aContactsCount: integer): TGroup;
begin
  Result := TGroup.Create;
  Result.Name := aName;
  Result.ContactsCount := aContactsCount;
  Groups.Add(Result);
end;

function TCore.AddNewSMSProfile(const aName: string): TSMSProfile;
begin
  Result := TSMSProfile.Create;
  Result.Name := aName;
  SMSProfiles.Add(Result);
end;

function TCore.CreateAddNewCampaign(const aName: string): TCampaign;
begin
  Result := TCampaign.Create(OnSMSSentTCampaign, OnCampaignActionTCampaign);
  Result.Name := aName;
  Campaigns.Add(Result);
end;

procedure TCore.UpdateProfilesAndGroups(aCampaign: TCampaign; const aProfiles, aGroups: string);
var
  vStrings: TArray<string>;
  vItem: TBaseCol;
  i: integer;
begin
  aCampaign.Groups.Clear;
  aCampaign.SMSProfiles.Clear;

  // add groups, find each group in list and add reference to class
  vStrings := aGroups.Split([SPLIT_CHAR]);
  for i := 0 to High(vStrings) do
  begin
    vItem := FindNameInList<TGroup>(vStrings[i], Groups);
    if vItem <> nil  then
      aCampaign.Groups.Add(TGroup(vItem));
  end;

  // same for profiles
  vStrings := aProfiles.Split([SPLIT_CHAR]);
  for i := 0 to High(vStrings) do
  begin
    vItem := FindNameInList<TSMSProfile>(vStrings[i], SMSProfiles);
    if vItem <> nil  then
      aCampaign.SMSProfiles.Add(TSMSProfile(vItem));
  end;
end;

function TCore.GenerateCampaignName: string;

  function FindCaption(const aText: string): boolean;
  var
    i: Integer;
  begin
    Result := false;
    for i := Campaigns.Count - 1 downto 0 do
    begin
      Result := CompareText(Campaigns.List[i].Name, aText) = 0;
      if Result then
        exit;
    end;
  end;

var
  vIndex: integer;
begin
  vIndex := Campaigns.Count;
  repeat
    inc(vIndex);
    Result := 'Campaign' + vIndex.ToString;
  until not FindCaption(Result);
end;

procedure TCore.DeleteGroup(aGroup: TGroup);
var
  i: integer;
begin
  for i := 0 to Campaigns.Count -1 do
  begin
    if Campaigns.List[i].DeleteGroup(aGroup) then
      Settings.SaveCampaignGroups(Campaigns.List[i].Name, Campaigns.List[i].GetGroupsString);
  end;

  Settings.DeleteGroup(aGroup.Name);
  Groups.Delete(Groups.IndexOf(aGroup));

  Settings.UpdateFile;
  Scheduler.RecheckCampaigns;
end;

procedure TCore.DeleteSMSProfile(aProfile: TSMSProfile);
var
  i: integer;
begin
  for i := 0 to Campaigns.Count -1 do
  begin
    if Campaigns.List[i].DeleteProfile(aProfile) then
      Settings.SaveCampaignProfiles(Campaigns.List[i].Name, Campaigns.List[i].GetProfilesString);
  end;

  Settings.DeleteSMSProfile(aProfile.Name);
  SMSProfiles.Delete(SMSProfiles.IndexOf(aProfile));

  Settings.UpdateFile;
  Scheduler.RecheckCampaigns;
end;

procedure TCore.DeleteCampaign(aCampaign: TCampaign);
begin
  Settings.DeleteCampaign(aCampaign.Name);
  Campaigns.Delete(Campaigns.IndexOf(aCampaign));
end;

function TCore.LoadContactsFromPhoneBook(aList: TList<TUDContact>): integer;
var
  vAddressBook: TAddressBook;
  vContacts: TAddressBookContacts;
  vContact: TUDContact;
  i: Integer;
begin
  aList.Clear;

  {$IF Defined(IOS) or Defined(ANDROID)}
  vAddressBook := TAddressBook.Create(nil);
  vContacts := TAddressBookContacts.Create;
  try
    vAddressBook.AllContacts(vContacts);
    for i := 0 to vContacts.Count - 1 do
    begin
      if vContacts.List[i].Phones.Count = 0 then Continue;
      vContact.ContactName := vContacts.List[i].DisplayName;
      vContact.Phone := vContacts.List[i].Phones[0].Number;
      aList.Add(vContact);
    end;
  finally
    vAddressBook.Free;  // <<
    { under ARC, this method isn't actually called since the compiler translates
      the call to be a mere nil assignment to the instance variable, which then calls _InstClear.
      Will be correclty free because Owner is nil}
    vContacts.Free;
  end;
  {$ELSE}
  // generate fake contacts for non Mobile systems
  for i := 1 to 10 do
  begin
    vContact.ContactName := 'TestContact' + i.ToString;
    vContact.Phone := '050' + Random(9999999).ToString;
    aList.Add(vContact);
  end;
  {$IFEND}
  Result := aList.Count;
end;

procedure TCore.OnCampaignActionTCampaign(aAction: TCampaignAction; aCampaign: TCampaign;
    var aStop: boolean);
begin
  // save new status - Completed = true and Enabled = false
  if aAction = caFinished then
  begin
    Settings.SaveCampaignFlags(aCampaign.Name, aCampaign.Enable, aCampaign.Completed,
      aCampaign.StartDateTime);
    Settings.UpdateFile;
  end;

  if Assigned(fOnCampAction) then
    fOnCampAction(aAction, aCampaign, aStop);

  if aAction = caFinished then
    Scheduler.StartTimerThread;
end;

procedure TCore.OnSMSSentTCampaign(aCampaign: TCampaign; aProfile: TSMSProfile; aGroup: TGroup;
      const aContact: TUDContact; aResult: TSMSError);
begin
  if Assigned(fOnSentSMS) then
    fOnSentSMS(aCampaign, aProfile, aGroup, aContact, aResult);
end;


// search for a name in TGroup, TProfile, NOT case sensetive
function TCore.FindNameInList<T>(const aName: string; aList: TObjectList<T>): T;
var
  i: Integer;
begin
  Result := nil;
  for i := 0 to aList.Count - 1 do
    if CompareText(TBaseCol(aList.List[i]).Name, aName) = 0 then
    begin
      Result := aList.List[i];
      break;
    end;
end;

end.
