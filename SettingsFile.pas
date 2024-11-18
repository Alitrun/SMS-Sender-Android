unit SettingsFile;

interface

uses
  IniFiles, IOUtils, Classes, SysUtils, System.Generics.Collections, Campaigns;

type
  TSettings = class
  strict private
    fIni: TMemIniFile;
    procedure OpenIniFile;
  public
    LastSetAlarm: TDateTime;
    constructor Create;
    destructor Destroy; override;
    procedure LoadSettings(out aLastAlarmDT: TDateTime);
    procedure SaveSettings(const aLastAlarmDT: TDateTime);

    procedure LoadAllFromIni(aAllGroups: TObjectList<TGroup>; aAllSMSProfiles: TObjectList<TSMSProfile>);

    procedure LoadContactsOfGroup(const aGroupName: string; out aContacts: TUPContactsAr);
    procedure SaveContactsOfGroup(const aNewGroupName, aOldGroupName: string; const aContacts: TUPContactsAr);
    procedure DeleteGroup(const aGroupName: string);

    function LoadProfileDescr(const aName: string): string;
    function LoadSMSProfile(const aProfileName: string): string;
    procedure SaveSMSProfile(const aNewName, aOldName, aDescription, aSMSText: string);
    procedure DeleteSMSProfile(const aName: string);

    procedure LoadCampaignsNames(aStrList: TStringList);
    function LoadCampaignDescr(const aName: string): string;
    procedure LoadCampaign(const aName: string;
        out aProfiles, aGroups: string;
        out aStartDate, aEndDate: TDateTime;
        out aRepeatCase: TRepeatCase;
        out aRepeatValue: integer;
        out aEnabled, aCompleted: boolean);
    procedure SaveCampaign(const aName, aOldName, aDescription, aProfiles, aGroups: string;
        aStartDate, aEndDate: TDateTime;
        aRepeatCase: TRepeatCase;
        aRepeatValue: integer;
        aEnabled: boolean);
    procedure SaveCampaignProfiles(const aName, aProfiles: string);
    procedure SaveCampaignGroups(const aName, aGroups: string);
    procedure DeleteCampaign(const aName: string);
    procedure SaveCampaignFlags(const aName: string; aEnabled, aCompleted: boolean;
        aStartDate: TDateTime);
{$IFDEF DEBUG}
    procedure DeleteIni;
{$ENDIF}
    procedure UpdateFile;
    procedure CloseAndNilIni;
  end;


implementation

const
  FILE_USER_SETTINGS = 'user_settings.dat';   // c:\Users\Alex\AppData\Roaming\user_settings.dat
  SECT_GROUPS = 'Groups';

  SECT_PROFILES = 'TextProfiles';
  KEY_TEXT = 'text';
  KEY_SEC = 'RepeatSeconds';
  KEY_DAYS = 'RepeatDays';

  SECT_CAMPAIGNS = 'Campaigns';
  KEY_PROFILES = 'Profiles';
  KEY_GROUPS = 'Groups';
  KEY_START_DATE = 'StartDate';
  KEY_END_DATE = 'EndDate';
  KEY_REPEAT_VAL = 'RepeatVal';
  KEY_REPEAT_CASE = 'RepeatCase';
  KEY_ENABLED = 'Enable';
  KEY_COMPLETED = 'Completed';

  SECT_SETTINGS = 'Settings';
  KEY_LAST_ALARM_DATE = 'LastAlarm';

{ TSettings }

constructor TSettings.Create;
begin
  OpenIniFile;
  LoadSettings(LastSetAlarm);
end;

destructor TSettings.Destroy;
begin
  SaveSettings(LastSetAlarm);
  CloseAndNilIni;
  inherited;
end;

procedure TSettings.OpenIniFile;
begin
  if fIni = nil then
    fIni := TMemIniFile.Create(TPath.GetHomePath + TPath.DirectorySeparatorChar + FILE_USER_SETTINGS);
end;

procedure TSettings.CloseAndNilIni;
begin
  fIni.UpdateFile;
  FreeAndNil(fIni);
end;

procedure TSettings.UpdateFile;
begin
  fIni.UpdateFile;
end;

procedure TSettings.LoadSettings(out aLastAlarmDT: TDateTime);
begin
  OpenIniFile;
  aLastAlarmDT := fIni.ReadFloat(SECT_SETTINGS, KEY_LAST_ALARM_DATE, 0);
end;

procedure TSettings.SaveSettings(const aLastAlarmDT: TDateTime);
begin
  OpenIniFile;
  fIni.WriteFloat(SECT_SETTINGS, KEY_LAST_ALARM_DATE, aLastAlarmDT);
end;

procedure TSettings.LoadAllFromIni(aAllGroups: TObjectList<TGroup>; aAllSMSProfiles: TObjectList<TSMSProfile>);
var
  vGroup: TGroup;
  vSMSProfile: TSMSProfile;
  vStrList: TStringList;
  i: integer;
begin
  vStrList := TStringList.Create;
  OpenIniFile;
  try
    // add groups
    fIni.ReadSectionValues(SECT_GROUPS, vStrList);
    for i := 0 to vStrList.Count - 1 do
    begin
      vGroup := TGroup.Create;
      vGroup.Name := vStrList.Names[i];
      vGroup.ContactsCount := vStrList.ValueFromIndex[i].ToInteger;
      aAllGroups.Add(vGroup);
    end;

    // load sms profiles
    fIni.ReadSectionValues(SECT_PROFILES, vStrList);
    for i := 0 to vStrList.Count - 1 do
    begin
      vSMSProfile := TSMSProfile.Create;
      vSMSProfile.Name := vStrList.Names[i];
      // disabled Descriptions to save memory. Will load it with fast LoadProfilesAndDescr
      //vSMSProfile.Description := vStrList.ValueFromIndex[i];
      aAllSMSProfiles.Add(vSMSProfile);
    end;
  finally
    vStrList.Free;
  end;
end;

procedure TSettings.LoadCampaignsNames(aStrList: TStringList);
begin
  OpenIniFile;
  fIni.ReadSectionValues(SECT_CAMPAIGNS, aStrList);
end;

procedure TSettings.LoadContactsOfGroup(const aGroupName: string;
    out aContacts: TUPContactsAr);
var
  vStrList: TStringList;
  i: Integer;
begin
  vStrList := TStringList.Create;
  OpenIniFile;
  try
    fIni.ReadSectionValues(aGroupName, vStrList);
    SetLength(aContacts, vStrList.Count);
    for i := 0 to vStrList.Count - 1 do
    begin
      aContacts[i].ContactName := vStrList.Names[i];
      aContacts[i].Phone := vStrList.ValueFromIndex[i];
    end;
  finally
    vStrList.Free;
  end;
end;


{[Group1Name]
ContactName1=+38050123456
ContactName2=+38050555555}

procedure TSettings.SaveContactsOfGroup(const aNewGroupName, aOldGroupName: string;
        const aContacts: TUPContactsAr);
var
  I: Integer;
begin
  OpenIniFile;
  // delete old section with Group name
  if CompareText(aOldGroupName, aNewGroupName) <> 0 then
    DeleteGroup(aOldGroupName);

  fIni.EraseSection(aNewGroupName);
  for I := 0 to High(aContacts) do
    fIni.WriteString(aNewGroupName, aContacts[i].ContactName, aContacts[i].Phone);

  fIni.WriteString(SECT_GROUPS, aNewGroupName, Length(aContacts).ToString);
  fIni.UpdateFile;
end;

procedure TSettings.DeleteGroup(const aGroupName: string);
begin
  OpenIniFile;
  fIni.EraseSection(aGroupName);
  fIni.DeleteKey(SECT_GROUPS, aGroupName);
end;

{[TextProfiles]
Profile1Name=Description
Profile2Name=Description
                              }
function TSettings.LoadProfileDescr(const aName: string): string;
begin
  OpenIniFile;
  Result := fIni.ReadString(SECT_PROFILES, aName, '');
end;

function TSettings.LoadSMSProfile(const aProfileName: string): string;
begin
  OpenIniFile;
  Result := fIni.ReadString(aProfileName, KEY_TEXT, '');
end;

{
[TextProfiles]
Profile1Name=Descr
Profile2Name=Descr2

[Profile1Name]
text=SMS Text }

procedure TSettings.SaveSMSProfile(const aNewName, aOldName, aDescription, aSMSText: string);
begin
  OpenIniFile;
  // delete old section
  if CompareText(aOldName, aNewName) <> 0 then
    DeleteSMSProfile(aOldName);

  fIni.WriteString(SECT_PROFILES, aNewName, aDescription);
  fIni.WriteString(aNewName, KEY_TEXT, aSMSText );
  fIni.UpdateFile;
end;

procedure TSettings.DeleteSMSProfile(const aName: string);
begin
  OpenIniFile;
  fIni.EraseSection(aName);
  fIni.DeleteKey(SECT_PROFILES, aName);
end;

{[Campaigns]
Campaign1Name=Description
Campaign2Name=Description }


function TSettings.LoadCampaignDescr(const aName: string): string;
begin
  OpenIniFile;
  Result := fIni.ReadString(SECT_CAMPAIGNS, aName, '');
end;

procedure TSettings.SaveCampaignFlags(const aName: string; aEnabled, aCompleted: boolean;
    aStartDate: TDateTime);
begin
  OpenIniFile;
  fIni.WriteBool(aName, KEY_COMPLETED, aCompleted);
  fIni.WriteBool(aName, KEY_ENABLED, aEnabled);
  fIni.WriteFloat(aName, KEY_START_DATE, aStartDate);
end;

{[Campaign1Name]
Groups=Group1Name;Group2Name ;
Profiles=Profile1Name;Prof2
StartDateTime=45665.45687  ; must be always with dot ".", not "," or any other
EndDateTime=0
RepeatMin=0 ; repeat interval in minutes
}
procedure TSettings.LoadCampaign(const aName: string;
    out aProfiles, aGroups: string;
    out aStartDate, aEndDate: TDateTime;
    out aRepeatCase: TRepeatCase;
    out aRepeatValue: integer;
    out aEnabled, aCompleted: boolean);
begin
  OpenIniFile;
  aProfiles := fIni.ReadString(aName, KEY_PROFILES, '');
  aGroups := fIni.ReadString(aName, KEY_GROUPS, '');
  aStartDate := fIni.ReadFloat(aName, KEY_START_DATE, 0);
  aEndDate := fIni.ReadFloat(aName, KEY_END_DATE, 0);
  aRepeatCase := TRepeatCase(fIni.ReadInteger(aName, KEY_REPEAT_CASE, 0) );
  aRepeatValue := fIni.ReadInteger(aName, KEY_REPEAT_VAL, 0);
  aEnabled := fIni.ReadBool(aName, KEY_ENABLED, false);
  aCompleted := fIni.ReadBool(aName, KEY_COMPLETED, false);
end;

procedure TSettings.SaveCampaign(const aName, aOldName, aDescription, aProfiles, aGroups: string; aStartDate,
  aEndDate: TDateTime; aRepeatCase: TRepeatCase; aRepeatValue: integer; aEnabled: boolean);
begin
  OpenIniFile;
  // delete old section
  if CompareText(aOldName, aName) <> 0 then
    DeleteCampaign(aOldName);

  fIni.WriteString(SECT_CAMPAIGNS, aName, aDescription);
  fIni.WriteString(aName, KEY_PROFILES, aProfiles);
  fIni.WriteString(aName, KEY_GROUPS, aGroups);
  fIni.WriteFloat(aName, KEY_START_DATE, aStartDate);
  fIni.WriteFloat(aName, KEY_END_DATE, aEndDate);
  fIni.WriteInteger(aName, KEY_REPEAT_CASE, integer(aRepeatCase));
  fIni.WriteInteger(aName, KEY_REPEAT_VAL, aRepeatValue);
  fIni.WriteBool(aName, KEY_ENABLED, aEnabled);
  fIni.UpdateFile;
end;

procedure TSettings.SaveCampaignGroups(const aName, aGroups: string);
begin
  OpenIniFile;
  fIni.WriteString(aName, KEY_GROUPS, aGroups);
end;

procedure TSettings.SaveCampaignProfiles(const aName, aProfiles: string);
begin
  OpenIniFile;
  fIni.WriteString(aName, KEY_PROFILES, aProfiles);
end;

procedure TSettings.DeleteCampaign(const aName: string);
begin
  OpenIniFile;
  fIni.EraseSection(aName);
  fIni.DeleteKey(SECT_CAMPAIGNS, aName);
end;

{$IFDEF DEBUG}
procedure TSettings.DeleteIni;
begin
  FreeAndNil(fIni);
  {$WARNINGS OFF}
  // [DCC Hint] SettingsFile.pas(333): H2443 Inline function 'DeleteFile' has not been expanded because unit 'Posix.Unistd' is not specified in USES list
  DeleteFile(TPath.GetHomePath + TPath.DirectorySeparatorChar + FILE_USER_SETTINGS);
  {$WARNINGS ON}
end;
{$ENDIF}

end.
