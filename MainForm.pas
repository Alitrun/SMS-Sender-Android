unit MainForm;

interface

uses
  Core, SendSMS,
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.StdCtrls,
  FMX.ListBox, FMX.Layouts, FMX.TabControl, FMX.Utils,
  FMX.ListView.Types, FMX.ListView.Appearances, FMX.Dialogs,
  FMX.ListView.Adapters.Base, FMX.ListView, System.Generics.Collections,
  FMX.Edit, FMX.Controls.Presentation, System.ImageList, FMX.ImgList, System.Messaging,
  FMX.Ani, FMX.Objects, System.Rtti, FMX.Gestures, FMX.DialogService, Campaigns, FMX.ScrollBox,
  FMX.Memo, FMX.Platform,  FMX.Effects, IOUtils;

type
  TCurrentView = (cvNone, cvDashBoard,
                  cvGroups, cvContactsInGroup, cvConctactsInPhone,
                  cvTextProfiles, cvEditTextProfile,
                  cvCampaigns, cvEditCampaign, cvSelectGroupsOrProfiles,
                  cvLog);

  THelperListView = class helper for TListView
  public
    function FindCaption(const aText: string): boolean;
    function GenerateNewItemName(const aBaseStr: string): string;
    procedure Add(const aText, aDetail: string; const aMyData: TValue; aImageIndex: integer);
    function SelectedItemText: string;
    function SelectedMyData: TClass;
    function SelectedItemDetailText: string;
  end;

  // workaround for fixed widh Speedbuttons on Android
  TSpeedButton = class(FMX.StdCtrls.TSpeedButton)
  protected
    procedure AdjustFixedSize(const Ref: TControl); override;
  end;


  TfrmMain = class(TForm)
    lbMenu: TListBox;
    liLog: TListBoxItem;
    TabControl: TTabControl;
    tiMainList: TTabItem;
    tiDetailsList: TTabItem;
    lvMain: TListView;
    lvDetails: TListView;
    ebGroupName: TEdit;
    ImageList1: TImageList;
    ClearEditButton1: TClearEditButton;
    tiEditCampaign: TTabItem;
    tiCampaigns: TTabItem;
    lbCampaigns: TListBox;
    StyleBook1: TStyleBook;
    GestureManager1: TGestureManager;
    lblLoading: TText;
    tiEditSMSProfile: TTabItem;
    tiLog: TTabItem;
    memLog: TMemo;
    LayMainTabs: TLayout;
    btnDashboard: TSpeedButton;
    btnCampaigns: TSpeedButton;
    btnGroups: TSpeedButton;
    btnProfiles: TSpeedButton;
    tiDashboard: TTabItem;
    tbDetails: TToolBar;
    btnMenu: TSpeedButton;
    lblCaption: TLabel;
    btnBack: TSpeedButton;
    btnCreateNew: TSpeedButton;
    btnStopSending: TSpeedButton;
    Glyph1: TGlyph;
    ShadowEffect1: TShadowEffect;
    btnPrevLogs: TSpeedButton;
    procedure lbMenuItemClick(const Sender: TCustomListBox; const Item: TListBoxItem);
    procedure FormCreate(Sender: TObject);
    procedure lvDetailsUpdateObjects(const Sender: TObject; const AItem: TListViewItem);
    procedure btnBackClick(Sender: TObject);
    procedure lvMainUpdateObjects(const Sender: TObject; const AItem: TListViewItem);
    procedure lvMainDeletingItem(Sender: TObject; AIndex: Integer; var ACanDelete: Boolean);
    procedure lvMainItemClick(const Sender: TObject; const AItem: TListViewItem);
    procedure btnCreateNewClick(Sender: TObject);
    procedure lvDetailsItemClick(const Sender: TObject; const AItem: TListViewItem);
    procedure lbCampaignsGesture(Sender: TObject; const EventInfo: TGestureEventInfo; var Handled: Boolean);
    procedure lbCampaignsTap(Sender: TObject; const Point: TPointF);
    procedure lbCampaignsItemClick(const Sender: TCustomListBox; const Item: TListBoxItem);
    procedure FormActivate(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure FormKeyUp(Sender: TObject; var Key: Word; var KeyChar: Char; Shift: TShiftState);
    procedure FormResize(Sender: TObject);
    procedure btnMenuClick(Sender: TObject);
    procedure btnPrevLogsClick(Sender: TObject);
    procedure lvDetailsDblClick(Sender: TObject);
  private
    fCore: TCore;
    [weak] fCurrentEditGroup: TObject; // Group that user is editing in GUI
    procedure OnCampActionTCore(aAction: TCampaignAction; aCampaign: TCampaign; var aStop: boolean);
    procedure LoadGroupsToListView(aListView: TListView);
    procedure LoadProfilesToListView(aListView: TListView);
    procedure OnPressedEditButtonCampaignFrame(Sender: TObject);
    procedure DoOnClickCampaignSwitch(Sender: TObject);
    procedure OnClickTabButton(Sender: TObject);
    procedure PreloadContent(const Control: TControl);
    procedure ShowTabsButtons(aShow: boolean);
    procedure OnSentSMSTCore(aCampaign: TCampaign; aProfile: TSMSProfile; aGroup: TGroup;
      const aContact: TUDContact; aResult: TSMSError);

  private  // views
    fCurView: TCurrentView;
    procedure SetCurrentView(aValue: TCurrentView);
    procedure SetViewDashboard(aBack: boolean);
    procedure SetViewGroupsList(aBack: boolean);
    procedure SetViewContactsListInGroup(aBack: boolean);
    procedure SetViewContactsListInPhone(aBack: boolean);
    procedure SetViewTextProfilesList(aBack: boolean);
    procedure SetViewEditTextProfile(aBack: boolean);
    procedure SetViewCampaignsList(aBack: boolean);
    procedure SetViewEditCampaign(aBack: boolean);
    procedure SetViewSelectGroupsOrProfiles(aBack: boolean);
    procedure SetViewLog;
  private
    fAllLogLoaded: boolean; // if full log was loaded
    procedure AddToLog(const aText: string);
    procedure AppendAndSaveLog;

  public
    property CurrentView: TCurrentView read fCurView write SetCurrentView;
  end;

var
  frmMain: TfrmMain;

implementation

uses
  MainPageFrame, EditProfileFrame, EditCampaignFrame, Misc, DateUtils;

const
  CAP_GROUPS = 'Contact Groups';
  CAP_CONTACTS_IN_GROUP  = 'Contacts';
  CAP_CONTACTS_IN_PHONE = 'Phone Contacts';
  CAP_TEXT_PROFILES = 'Text Profiles';
  CAP_EDIT_TEXT_PROFILE = 'Edit Profile';
  CAP_CAMPAIGNS = 'Campaigns';
  CAP_EDIT_CAMPAIGN = 'Edit Campaign';
  CAP_LOG = 'Log';
  FILENAME_LOG = 'Log.txt';
  
{$R *.fmx}


procedure TfrmMain.PreloadContent(const Control: TControl);
var
  I: Integer;
begin
  if Control is TStyledControl then
    TStyledControl(Control).ApplyStyleLookup;
  for I := 0 to Control.ControlsCount - 1 do
    PreloadContent(Control.Controls.List[I]);
end;

procedure TfrmMain.FormCreate(Sender: TObject);
var
  vStartedfromAlarm: boolean;
begin
  vStartedfromAlarm := StartedFromAlarmManager;
  { TurnOnAndKeepScreen proc was moved to OnCampActionTCore on caBeforeStart }

  fCore := TCore.Create;
  fCore.OnCampaignAction := OnCampActionTCore;
  fCore.OnSentSMS := OnSentSMSTCore;
  btnBack.Visible := false;

  btnDashboard.OnClick := OnClickTabButton;
  btnCampaigns.OnClick := OnClickTabButton;
  btnGroups.OnClick := OnClickTabButton;
  btnProfiles.OnClick := OnClickTabButton;
  btnDashboard.Tag := 1;
  btnCampaigns.Tag := 2;
  btnGroups.Tag := 3;
  btnProfiles.Tag := 4;

  // need this once for skin Jet, because this ListView loads black font
  lvDetails.ApplyStyleLookup;

  if vStartedfromAlarm then
    CurrentView := cvLog
  else
    btnDashboard.Click;
    //CurrentView := cvDashBoard;
end;

procedure TfrmMain.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  AppendAndSaveLog;
  
  fCore.DisposeOf;
  CanClose := true;
end;

procedure TfrmMain.FormActivate(Sender: TObject);
begin
  fCore.Scheduler.StartTimerThread;
  OnActivate := nil;
end;

procedure TfrmMain.FormKeyUp(Sender: TObject; var Key: Word; var KeyChar: Char; Shift: TShiftState);
begin
  if Key = vkHardwareBack then
    if IsKeyboardVisible then exit
    else
      if lbMenu.Visible then
        btnMenu.Click
      else
        if btnBack.Visible then
        begin
          btnBackClick(Self);
          Key := 0;
        end;
end;

procedure TfrmMain.LoadGroupsToListView(aListView: TListView);
var
  i: Integer;
begin
  aListView.BeginUpdate;
  try
    for I := 0 to fCore.Groups.Count - 1 do
      aListView.Add(fCore.Groups.List[i].Name,
         'Contacts: ' + fCore.Groups.List[i].ContactsCount.ToString, TClass(fCore.Groups.List[i]),  1);
   // cast it to TClass, cause ListItem does not add TObject to his Data except Bitmaps and some other spec Objects.
  finally
    aListView.EndUpdate;
  end;
end;

procedure TfrmMain.LoadProfilesToListView(aListView: TListView);
var
  i: integer;
begin
  aListView.BeginUpdate;
  try
    // profiles names already loaded in LoadAllIni, now load descriptions strings -
    // we did not loaded them before to save memory
    for i := 0 to fCore.SMSProfiles.Count - 1 do
    begin
       aListView.Add(fCore.SMSProfiles.List[i].Name,
                    fCore.Settings.LoadProfileDescr(fCore.SMSProfiles.List[i].Name),
                    TClass(fCore.SMSProfiles.List[i]),  2);
    end;
  finally
    aListView.EndUpdate;
  end;
end;

procedure TfrmMain.OnClickTabButton(Sender: TObject);
begin
  Assert(Sender is TSpeedButton);
  case TSpeedButton(Sender).Tag of
    1: CurrentView := cvDashBoard;
    2: CurrentView := cvCampaigns;
    3: CurrentView := cvGroups;
    4: CurrentView := cvTextProfiles;
    else
      raise Exception.Create('unknown tab button');
  end;
end;


{$region 'Views'}

procedure TfrmMain.SetCurrentView(aValue: TCurrentView);

  procedure FreeSomeData;
  begin
    if aValue in [cvCampaigns, cvLog] then
    begin
      lvMain.Items.Clear;
      lvDetails.Items.Clear;
    end;
  end;

begin
  // animation - fade out previous screen
  if not btnBack.Visible and
     (aValue in [cvDashBoard, cvCampaigns, cvGroups, cvTextProfiles]) and
     (gFrameDash <> nil) then
  begin
    TAnimator.AnimateFloatWait(TabControl, 'Opacity', 0, 0.10, TAnimationType.&In,
       TInterpolationType.Quintic);
  end;

  FreeSomeData;
  if lbMenu.Visible then
    lbMenu.Visible := false;
  fCurView := aValue;
  ShowTabsButtons(not (aValue in [cvDashBoard, cvContactsInGroup, cvConctactsInPhone, cvEditTextProfile,
      cvEditCampaign, cvSelectGroupsOrProfiles]));

  case aValue of
    cvDashBoard              : SetViewDashboard(btnBack.StaysPressed);
    cvGroups                 : SetViewGroupsList(btnBack.StaysPressed);
    cvContactsInGroup        : SetViewContactsListInGroup(btnBack.StaysPressed);
    cvConctactsInPhone       : SetViewContactsListInPhone(btnBack.StaysPressed);
    cvTextProfiles           : SetViewTextProfilesList(btnBack.StaysPressed);
    cvEditTextProfile        : SetViewEditTextProfile(btnBack.StaysPressed);
    cvCampaigns              : SetViewCampaignsList(btnBack.StaysPressed);
    cvEditCampaign           : SetViewEditCampaign(btnBack.StaysPressed);
    cvSelectGroupsOrProfiles : SetViewSelectGroupsOrProfiles(btnBack.StaysPressed);
    cvLog                    : SetViewLog;
  end;

  // before setting btnBack.Visible! Because of using prev. result of btnBack.Visible
  if aValue in [cvContactsInGroup, cvConctactsInPhone, cvEditTextProfile,
                                       cvEditCampaign, cvSelectGroupsOrProfiles] then
    fCore.Scheduler.Stop
  else
    if btnBack.Visible then
      fCore.Scheduler.RecheckCampaigns;

  btnBack.Visible := aValue in [cvContactsInGroup, cvConctactsInPhone, cvEditTextProfile,
      cvEditCampaign, cvSelectGroupsOrProfiles];

  btnCreateNew.Visible := fCurView in [cvGroups, cvContactsInGroup, cvTextProfiles, cvCampaigns];
  btnMenu.Visible := not btnBack.Visible and not (fCurView in [cvDashBoard]);
  btnPrevLogs.Visible := (fCurView = cvLog) and not fAllLogLoaded;

  //animation
  if fCurView in [cvDashBoard, cvCampaigns, cvGroups, cvTextProfiles] then
    TAnimator.AnimateFloat(TabControl, 'Opacity', 1, 0.18, TAnimationType.&In,
       TInterpolationType.Quintic);
end;

procedure TfrmMain.SetViewDashboard(aBack: boolean);
begin
  lblCaption.Text := '';
  btnDashboard.IsPressed := true;
  if gFrameDash = nil then
  begin
    gFrameDash := TframeMainPage.Create(nil);
    gFrameDash.OnClickButton := procedure (aSender: TObject)
    begin
      if TControl(aSender).Name = 'btnCampaigns' then
        CurrentView := cvCampaigns
      else if TControl(aSender).Name = 'btnGroups' then
        CurrentView := cvGroups
      else if TControl(aSender).Name = 'btnProfiles' then
        CurrentView := cvTextProfiles
      else Assert(false);
    end;
  end;
  gFrameDash.btnGroups.StylesData['num'] := fCore.Groups.Count.ToString;
  gFrameDash.btnProfiles.StylesData['num'] := fCore.SMSProfiles.Count.ToString;
  gFrameDash.btnCampaigns.StylesData['num'] := fCore.Campaigns.Count.ToString;
  // temporary set it in this tab - because this frame will be deleted after have been showed
  tiDashboard.AddObject(gFrameDash);
  TabControl.ActiveTab := tiDashboard;
  gFrameDash.btnCampaigns.SetFocus;
end;

procedure TfrmMain.SetViewGroupsList(aBack: boolean);

  procedure SaveUserDataToFile(const aGroupName: string);
  var
    i: Integer;
    vContacts: TUPContactsAr;
    vSelGroup: TGroup;
  begin
    // fCurrentEditObj contains selected TGroup (to edit) - btw lvMain now does not contain Groups -
    //  instead of groups now it contains PhoneContacts (we share listViews for perfomance)
    vSelGroup := (fCurrentEditGroup as TGroup);
    // Create New Group?
    if vSelGroup = nil then
      vSelGroup := fCore.AddNewGroup(aGroupName, lvDetails.ItemCount);

    SetLength(vContacts, lvDetails.ItemCount);
    for i := 0 to lvDetails.ItemCount - 1 do
    begin
      vContacts[i].ContactName := lvDetails.Items[i].Text;
      vContacts[i].Phone := lvDetails.Items[i].Data['0'].ToString;
    end;
    vSelGroup.ContactsCount := lvDetails.ItemCount;
    if Length(vContacts) > 0 then
      fCore.Settings.SaveContactsOfGroup(aGroupName, vSelGroup.Name, vContacts);

    // Maybe user changed name?
    vSelGroup.Name := aGroupName;
  end;

begin
  btnGroups.IsPressed := true;
  if aBack then
    SaveUserDataToFile(ebGroupName.Text);

  fCurrentEditGroup := nil;
  lvMain.Items.Clear;
  lvMain.ItemAppearanceName := TAppearanceNames.ImageListItemBottomDetail;
  lvMain.ItemAppearanceObjects.ItemObjects.Accessory.AccessoryType := TAccessoryType.More;
  lvMain.CanSwipeDelete := true;

  LoadGroupsToListView(lvMain);

  if aBack then
    TabControl.SetActiveTabWithTransition(tiMainList, TTabTransition.Slide,
        TTabTransitionDirection(aBack))
  else
    TabControl.ActiveTab := tiMainList; // from main menu - no animation

  lblCaption.Text := CAP_GROUPS;
end;

procedure TfrmMain.SetViewContactsListInGroup(aBack: boolean);

  //  PhoneContacts are loaded in lvMain, now copy them to lvDetails
  procedure LoadCheckedFromPhoneContacts;
  var
    i: Integer;
    vStr: string;
  begin
    Assert(lvMain.ItemAppearanceObjects.ItemObjects.Accessory.AccessoryType = TAccessoryType.Checkmark);
    lvDetails.BeginUpdate;
    try
      for i := 0 to lvMain.Items.Count - 1 do
      if lvMain.Items[i].Objects.AccessoryObject.Visible then
      begin
        vStr := lvMain.Items[i].Text;
        if lvDetails.FindCaption(vStr) then Continue;

        lvDetails.Add(vStr, '', lvMain.Items[i].Data['0'].ToString, 0);
      end;
    finally
      lvDetails.EndUpdate;
    end;
  end;

  procedure LoadContactsOfGroupFromFile;
  var
    vContacts: TUPContactsAr;
    i: Integer;
  begin
    fCore.Settings.LoadContactsOfGroup(lvMain.SelectedItemText, vContacts);
    lvDetails.BeginUpdate;
    try
      for i := 0 to High(vContacts) do
        lvDetails.Add(vContacts[i].ContactName, '', vContacts[i].Phone, 0);
    finally
      lvDetails.EndUpdate;
    end;
  end;

begin
  lvDetails.ItemAppearanceName := TAppearanceNames.ImageListItem;
  lvDetails.ItemAppearanceObjects.ItemObjects.Accessory.AccessoryType := TAccessoryType.Checkmark;
  lvDetails.CanSwipeDelete := true;

  ebGroupName.Visible := true;
  if aBack then
    LoadCheckedFromPhoneContacts  // add to exists items in lv
  else
  // editing Group or new Group
  begin
    lvDetails.Items.Clear;

    if btnCreateNew.StaysPressed then
      ebGroupName.Text := lvMain.GenerateNewItemName('Group')
    else
    begin
      // save Group TObject pointer that was saved in Mydata (data['0']) in var. because we will use lvMain
      // (where groups are now) for another purpose
      fCurrentEditGroup := TObject(lvMain.SelectedMyData);
      Assert(fCurrentEditGroup <> nil);
      ebGroupName.Text := (fCurrentEditGroup as TGroup).Name;
      LoadContactsOfGroupFromFile;
    end;
  end;

  TabControl.SetActiveTabWithTransition(tiDetailsList, TTabTransition.Slide,
    TTabTransitionDirection(aBack));

  lblCaption.Text := CAP_CONTACTS_IN_GROUP;
end;

// load to first ListView - lvMain (where groups were)
procedure TfrmMain.SetViewContactsListInPhone(aBack: boolean);
var
  vStr: string;
begin
  lvMain.Items.Clear;
  lvMain.ItemAppearanceName := TAppearanceNames.ImageListItem;
  lvMain.ItemAppearanceObjects.ItemObjects.Accessory.AccessoryType := TAccessoryType.Checkmark;
  lvMain.CanSwipeDelete := false;

  TabControl.SetActiveTabWithTransition(tiMainList, TTabTransition.Slide,
    TTabTransitionDirection(aBack));

  // load contacts from Phone book.

  vStr := lblCaption.Text;
  lblCaption.Text := 'Loading phone book...';
  btnBack.Enabled := false;
  Application.ProcessMessages;

  // workaround: after taped on button - anuimation of tapping is freezing
  TThread.CreateAnonymousThread(procedure ()
  var
    vList: TList<TUDContact>;
  begin
    vList := TList<TUDContact>.Create;
    try
      fCore.LoadContactsFromPhoneBook(vList);

      TThread.Synchronize(nil,
      procedure ()
      var
        vContact: TUDContact;
      begin
        lvMain.BeginUpdate;
        try
          for vContact in vList do
          begin
            lvMain.Add(vContact.ContactName, '', vContact.Phone, 0 );
          end;
        finally
          lvMain.EndUpdate;
          lblCaption.Text := vStr;
          btnBack.Enabled := true;
          lblCaption.Text := CAP_CONTACTS_IN_PHONE;
        end;
      end);
    finally
      vList.Free;
    end;
  end).Start;

end;

// aka Text Profiles
procedure TfrmMain.SetViewTextProfilesList(aBack: boolean);

  procedure SaveTextProfileToFile(const aProfileName: string);
  var
    vSMSProfile: TSMSProfile;
  begin
    fCore.Settings.SaveSMSProfile(aProfileName, lvMain.SelectedItemText, gEditProfile.ebDescript.Text,
      gEditProfile.memText.Text);

    vSMSProfile := TSMSProfile(lvMain.SelectedMyData);
    // need create new profile?
    if vSMSProfile = nil then
      vSMSProfile := fCore.AddNewSMSProfile(aProfileName);
    vSMSProfile.Name := aProfileName;
  end;

begin
  btnProfiles.IsPressed := true;
  if aBack then
  begin
    SaveTextProfileToFile(gEditProfile.ebProfileName.Text);
    gEditProfile.ResetForm;
  //  gEditProfile.Parent := nil;
  end;
  lvMain.Items.Clear;
  lvMain.ItemAppearanceName := TAppearanceNames.ImageListItemBottomDetail;
  lvMain.ItemAppearanceObjects.ItemObjects.Accessory.AccessoryType := TAccessoryType.More;
  lvMain.CanSwipeDelete := true;
  LoadProfilesToListView(lvMain);

  if aBack then
    TabControl.SetActiveTabWithTransition(tiMainList, TTabTransition.Slide,
        TTabTransitionDirection(aBack))
  else
    TabControl.ActiveTab := tiMainList; // from main menu - no animation

  lblCaption.Text := CAP_TEXT_PROFILES;
end;

{Message Hint 'не забудь потом очищать все списки при переходе ан '}
procedure TfrmMain.SetViewEditTextProfile(aBack: boolean);
begin
  if gEditProfile = nil then
  begin
    lblLoading.Visible := true;
    gEditProfile := TframeEditProfile.Create(nil);
    tiEditSMSProfile.AddObject(gEditProfile);
  end;
  gEditProfile.ResetForm;
  if btnCreateNew.StaysPressed then
    gEditProfile.ebProfileName.Text := lvMain.GenerateNewItemName('Profile')
  else
  begin   // edit
    gEditProfile.ebProfileName.Text := lvMain.SelectedItemText;
    gEditProfile.memText.Text := fCore.Settings.LoadSMSProfile(lvMain.SelectedItemText);
    gEditProfile.ebDescript.Text := lvMain.SelectedItemDetailText;
  end;

  Assert(gEditProfile.ebProfileName.Text <> '');
  TabControl.SetActiveTabWithTransition(tiEditSMSProfile, TTabTransition.Slide,
    TTabTransitionDirection(aBack));
end;

procedure TfrmMain.SetViewCampaignsList(aBack: boolean);

  procedure SaveCampaignToFile(const aCampaignName: string);
  var
    vCampaign: TCampaign;
    vOldName: string;
  begin
    if lbCampaigns.Selected = nil then
      vCampaign := fCore.CreateAddNewCampaign(aCampaignName)
    else
      vCampaign := TCampaign(lbCampaigns.Selected.Tag);

    vOldName := vCampaign.Name;
    vCampaign.Name := aCampaignName;
    vCampaign.StartDateTime := gEditCampaignFrame.GetDateTimeStart;
    vCampaign.EndDateTime := gEditCampaignFrame.GetDateTimeEnd;
    vCampaign.RepeatCase := gEditCampaignFrame.RepeatCase;
    vCampaign.RepeatValue := Trunc(gEditCampaignFrame.sbRepeatNum.Value);
    fCore.UpdateProfilesAndGroups(vCampaign,
                         gEditCampaignFrame.lblProfiles.Text,
                         gEditCampaignFrame.lblGroups.Text);
    // if new date was set - unmark Completed flag
    if vCampaign.Completed then
      vCampaign.Completed := vCampaign.StartDateTime < Now;

    vCampaign.CheckAndSetDisabled(Now);
    fCore.Settings.SaveCampaign(vCampaign.Name,
          vOldName,
          gEditCampaignFrame.ebDescript.Text,
          gEditCampaignFrame.lblProfiles.Text,
          gEditCampaignFrame.lblGroups.Text,
          vCampaign.StartDateTime,
          vCampaign.EndDateTime,
          vCampaign.RepeatCase,
          vCampaign.RepeatValue,
          vCampaign.Enable);
  end;

const
  GROUPS_PROFILES = 'Profiles: %d, Groups: %d';
  START_DT = 'Start on %s at ';
var
  i: integer;
  vItem: TListBoxItem;
  vCampaign: TCampaign;
  vStartDateText: string;
  vSwitch : TSwitch;
  vCurDT: TDateTime;
begin
  btnCampaigns.IsPressed := true;
  if aBack then
    SaveCampaignToFile(gEditCampaignFrame.ebCampaignName.Text);

  vCurDT := Now;
  lbCampaigns.BeginUpdate;
  lbCampaigns.Clear;
  try
    for i := 0 to fCore.Campaigns.Count - 1 do
    begin
      vCampaign := fCore.Campaigns[i];

      if vCampaign.Completed then
        vStartDateText := 'Completed'
      else
        if vCampaign.IsExpired(vCurDT) then
           vStartDateText := 'Expired'
        else
          vStartDateText := Format(START_DT, [DateToStr(vCampaign.StartDateTime)]) +
              FormatDateTime(FormatSettings.ShortTimeFormat, vCampaign.StartDateTime);

      vItem := TListBoxItem.Create(nil);
       vItem.Parent:= lbCampaigns;
      lbCampaigns.AddObject(vItem);
      vItem.StyleLookup := '1CampaignItem';
      vItem.Text := vCampaign.Name;
      vItem.StylesData['descript'] := fCore.Settings.LoadCampaignDescr(vCampaign.Name);
      vItem.StylesData['details'] := Format(GROUPS_PROFILES,
         [vCampaign.SMSProfiles.Count, vCampaign.Groups.Count]);
      vItem.StylesData['sdate'] := vStartDateText;
      if vCampaign.Enable then
        vItem.ImageIndex := 3
      else
        vItem.ImageIndex := 5;

      vItem.Tag := NativeInt(vCampaign);
      vItem.NeedStyleLookup;
      vItem.ApplyStyleLookup; // without this, FindStyleResource will return nil

      vSwitch := vItem.FindStyleResource('switch') as TSwitch;
      Assert(vSwitch <> nil);
      vSwitch.IsChecked := vCampaign.Enable;
      vSwitch.OnClick := DoOnClickCampaignSwitch;
   // vItem.StylesData['switch.OnClick'] := TValue.From<TNotifyEvent>(DoOnClickCampaignSwitch);
     { How to get access to component in TListItem?
      Glyph http://stackoverflow.com/questions/35380936/firemonkey-use-stylesdata-to-set-property-of-array-object-in-style
     }
    end;
  finally
    lbCampaigns.EndUpdate;
  end;
  if aBack then
    TabControl.SetActiveTabWithTransition(tiCampaigns, TTabTransition.Slide,
        TTabTransitionDirection(aBack))
  else
    TabControl.ActiveTab := tiCampaigns; // from main menu - no animation

  lblCaption.Text := CAP_CAMPAIGNS;
end;

procedure TfrmMain.SetViewEditCampaign(aBack: boolean);


  // result := ItemName1;Item2;item3;
  function GetAllLVItemsInOneString(aLV: TListView): string;
  var
    i: Integer;
  begin
    Result := '';
    for i := 0 to aLV.Items.Count - 1 do
      if aLV.Items[i].Objects.AccessoryObject.Visible then
        Result := Result + aLV.Items[i].Text + SPLIT_CHAR;
  end;

  procedure LoadCampaignToEditFrame;
  var
    vCampaign: TCampaign;
  begin
    vCampaign := TCampaign(lbCampaigns.Selected.Tag);

    with gEditCampaignFrame do
    begin
      ebCampaignName.Text := vCampaign.Name;
      ebDescript.Text := fCore.Settings.LoadCampaignDescr(vCampaign.Name);
      lblProfiles.Text := vCampaign.GetProfilesString;
      lblGroups.Text := vCampaign.GetGroupsString;
      DateEditStart.Date := vCampaign.StartDateTime;
      TimeEditStart.Time := Frac(vCampaign.StartDateTime);

      gEditCampaignFrame.RepeatCase := vCampaign.RepeatCase;
      gEditCampaignFrame.sbRepeatNum.Value := vCampaign.RepeatValue;

      if vCampaign.RepeatCase <> rcNone then
        if vCampaign.EndDateTime = 0 then
        begin
          // repeat forever
          cbExpires.ItemIndex := 0;
        end
        else  // repeat by date
        begin
          cbExpires.ItemIndex := 1;
          deRepeatDateEnd.Date := vCampaign.EndDateTime;
          teRepeatTimeEnd.Time := Frac(vCampaign.EndDateTime);
        end;
    end;
  end;

begin
  // first loading
  if gEditCampaignFrame = nil then
  begin
    gEditCampaignFrame := TFrameEditCampaign.Create(nil);
    gEditCampaignFrame.OnPressedEditButton := OnPressedEditButtonCampaignFrame;
    Application.ProcessMessages;
    // First loading - show "loading..." text
    TabControl.SetActiveTabWithTransition(tiEditCampaign, TTabTransition.Slide,
      TTabTransitionDirection(false));
    Application.ProcessMessages;
  end;

  // after selectable list of groups or profiles
  if aBack then
  begin
    gEditCampaignFrame.GlowRed.Enabled := false;
    if gEditCampaignFrame.btnEditGroups.StaysPressed then
      gEditCampaignFrame.lblGroups.Text := GetAllLVItemsInOneString(lvDetails);
    if gEditCampaignFrame.btnEditProfiles.StaysPressed then
       gEditCampaignFrame.lblProfiles.Text := GetAllLVItemsInOneString(lvDetails);

    gEditCampaignFrame.btnEditGroups.StaysPressed := false;
    gEditCampaignFrame.btnEditProfiles.StaysPressed := false;
  end
  else
  begin
    gEditCampaignFrame.BeginUpdate;
    gEditCampaignFrame.lb.BeginUpdate;
    try
      gEditCampaignFrame.ResetForm;
      if btnCreateNew.StaysPressed then
        // new campaign
        gEditCampaignFrame.ebCampaignName.Text := fCore.GenerateCampaignName
      else
       // edit campaign
      begin
        Assert(lbCampaigns.Selected <> nil);
        if lbCampaigns.Selected = nil then exit;
          LoadCampaignToEditFrame;
      end;
    finally
      gEditCampaignFrame.lb.EndUpdate;
      gEditCampaignFrame.EndUpdate;
    end;

    // first loading
    if gEditCampaignFrame.Parent = nil then
    begin
      lblLoading.Visible := false;
      gEditCampaignFrame.Parent := tiEditCampaign;
   //   tiEditCampaign.AddObject(gEditCampaignFrame); // because on that
      TabControl.ActiveTab := tiEditCampaign;
      lblCaption.Text := CAP_EDIT_CAMPAIGN;
      Application.ProcessMessages; // because listboxgroupheader height will not be set correctly
      exit;
    end;
  end;

  TabControl.SetActiveTabWithTransition(tiEditCampaign, TTabTransition.Slide,
    TTabTransitionDirection(aBack));
  lblCaption.Text := CAP_EDIT_CAMPAIGN;
end;

procedure TfrmMain.OnPressedEditButtonCampaignFrame(Sender: TObject);
begin
  CurrentView := cvSelectGroupsOrProfiles;
end;

procedure TfrmMain.SetViewSelectGroupsOrProfiles(aBack: boolean);
begin
  lvDetails.Items.Clear;
  lvDetails.ItemAppearanceName := TAppearanceNames.ListItem;
  lvDetails.ItemAppearanceObjects.ItemObjects.Accessory.AccessoryType := TAccessoryType.Checkmark;
  lvDetails.CanSwipeDelete := false;
  ebGroupName.Visible := false;

  if gEditCampaignFrame.btnEditGroups.StaysPressed then
  begin
    LoadGroupsToListView(lvDetails);
    lblCaption.Text := CAP_GROUPS;
  end;
  if gEditCampaignFrame.btnEditProfiles.StaysPressed then
  begin
    LoadProfilesToListView(lvDetails);
    lblCaption.Text := CAP_TEXT_PROFILES;
  end;

  TabControl.SetActiveTabWithTransition(tiDetailsList, TTabTransition.Slide,
    TTabTransitionDirection(aBack));
end;

procedure TfrmMain.SetViewLog;
begin
  TabControl.ActiveTab := tiLog;
  lblCaption.Text := CAP_LOG;
  btnDashboard.IsPressed := false;
  btnCampaigns.IsPressed := false;
  btnGroups.IsPressed := false;
  btnProfiles.IsPressed := false;
end;


{$endregion}


procedure TfrmMain.ShowTabsButtons(aShow: boolean);
begin
  if LayMainTabs.Visible = aShow then exit;
  if aShow then
  begin
    LayMainTabs.Visible := true;
    LayMainTabs.Opacity:= 0;                          // 0.2
    TAnimator.AnimateFloat(LayMainTabs, 'Opacity', 1, 0.3, TAnimationType.&In,
      TInterpolationType.Quintic);
  end
  else
  begin
  //  TAnimator.AnimateFloat(LayMainTabs, 'Opacity', 0, 0.2, TAnimationType.&In,
    //  TInterpolationType.Quintic);
    LayMainTabs.Visible := false;
  end;
end;

procedure TfrmMain.btnBackClick(Sender: TObject);
begin
  case CurrentView of
    cvEditTextProfile: if not gEditProfile.CanClose then exit;
    cvEditCampaign: if not gEditCampaignFrame.CanClose then exit;
  end;
  btnBack.StaysPressed := true;
  CurrentView := Pred(CurrentView);
  btnBack.StaysPressed := false;
end;

// create new group, add new Contacts or campaign

procedure TfrmMain.btnCreateNewClick(Sender: TObject);
begin
  btnCreateNew.StaysPressed := true;
  case fCurView of
    cvGroups          : CurrentView := cvContactsInGroup;
    cvContactsInGroup : CurrentView := cvConctactsInPhone;
    cvTextProfiles    : CurrentView := cvEditTextProfile;
    cvCampaigns       :
    begin
      if (fCore.Groups.Count = 0) or (fCore.SMSProfiles.Count = 0) then
        ShowMessage('To create a Campaign you must have at least one Group and one SMS Profile.')
      else
      begin
        lbCampaigns.ItemIndex := -1;
        CurrentView := cvEditCampaign;
      end;
    end;
  end;
  btnCreateNew.StaysPressed := false;
end;

procedure TfrmMain.btnMenuClick(Sender: TObject);
begin
  lbMenu.Visible := not lbMenu.Visible;
  if lbMenu.Visible then
  begin
    lbMenu.BringToFront;
    lbMenu.ItemIndex := -1;
  end;
end;

procedure TfrmMain.lbMenuItemClick(const Sender: TCustomListBox; const Item: TListBoxItem);
begin
  if Item <> nil then
  begin
   case Item.Index of
     0: CurrentView := cvLog;
   end;
  end;
end;

{$region 'ListViews actions'}


// clicked on TSwitched in lbCampaign
procedure TfrmMain.DoOnClickCampaignSwitch(Sender: TObject);

  function FindItemParent(Obj: TFmxObject; ParentClass: TClass): TFmxObject;
  begin
    Result := nil;
    if Assigned(Obj.Parent) then
      if Obj.Parent.ClassType = ParentClass then
        Result := Obj.Parent
      else
        Result := FindItemParent(Obj.Parent, ParentClass);
  end;

  procedure SetSwith(aSwitch: TSwitch; aChecked: boolean);
  begin
    TThread.CreateAnonymousThread ( procedure // the animation and a crappy implementation prevent downshifting
    begin
      TThread.Queue( nil , procedure
      begin
        aSwitch.IsChecked := aChecked;
      end );
    end ).Start;
  end;

var
  vItem : TListBoxItem;
  vChecked: boolean;
begin
  vItem := TListBoxItem( FindItemParent(TFmxObject(Sender), TListBoxItem) );
  Assert(vItem <> nil);

  if Assigned(vItem) then
  begin
    vChecked := TSwitch(Sender).IsChecked;
    if vChecked then
    begin
      if TCampaign(vItem.Tag).Completed or TCampaign(vItem.Tag).IsExpired(Now) then
      begin
        ShowMessage('Campaign is already completed or expired. Please set new start\end dates.');
        vChecked := false;
      end;
      if (TCampaign(vItem.Tag).Groups.Count = 0) or (TCampaign(vItem.Tag).SMSProfiles.Count = 0) then
      begin
        ShowMessage('Number of Groups or SMS Profiles in this Campaign must be larger than 0.');
        vChecked := false;
      end;
    end;

    SetSwith(TSwitch(Sender), vChecked);
    // if we did not change switch in this proc
    if TSwitch(Sender).IsChecked = vChecked then
    begin
      TCampaign(vItem.Tag).Enable := vChecked;
      if vChecked then
        vItem.ImageIndex := 3
      else
        vItem.ImageIndex := 5;
      fCore.Scheduler.RecheckCampaigns;
    end;
  end;
end;

procedure TfrmMain.lbCampaignsTap(Sender: TObject; const Point: TPointF);
var
  vItem: TListBoxItem;
  vPos: TPointF;
begin
  vPos := ScreenToClient(Point);
  vItem := lbCampaigns.ItemByPoint(vPos.X, vPos.Y);
  if vItem = nil then exit;

  lbCampaigns.ItemIndex := vItem.Index;
  CurrentView := cvEditCampaign;
end;

procedure TfrmMain.lbCampaignsItemClick(const Sender: TCustomListBox; const Item: TListBoxItem);
begin
{$IFDEF MSWINDOWS}
  if Item = nil then exit;
  CurrentView := cvEditCampaign;
{$ENDIF}
end;

procedure TfrmMain.lbCampaignsGesture(Sender: TObject; const EventInfo: TGestureEventInfo;
  var Handled: Boolean);
begin
  if lbCampaigns.Selected = nil then exit;
  if EventInfo.GestureID in [1, 2] then // right to left
  begin

    TDialogService.MessageDialog('Are you sure you want to delete campaign "' + TCampaign(lbCampaigns.Selected.Tag).Name + '"?',
        TMsgDlgType.mtWarning,
        [TMsgDlgBtn.mbYes, TMsgDlgBtn.mbNo],
        TMsgDlgBtn.mbNo,
        0,
        procedure(const AResult: TModalResult)
        var
          vCampaign: TCampaign;
        begin
          if aResult = mrYES then
          begin
            Assert(lbCampaigns.Selected <> nil);
            vCampaign := TCampaign(lbCampaigns.Selected.Tag);
            lbCampaigns.Items.Delete(lbCampaigns.Selected.Index);
            fCore.DeleteCampaign(vCampaign);
          end;
        end
    );

    Handled := true;
  end;
end;


// we're using same listbox for various purposes (2 listboxes, and switch between them)
procedure TfrmMain.lvMainDeletingItem(Sender: TObject; AIndex: Integer; var ACanDelete: Boolean);
begin
  case CurrentView of
    cvGroups: fCore.DeleteGroup( TGroup(lvMain.Items[AIndex].Data['0'].AsClass) );
    cvTextProfiles: fCore.DeleteSMSProfile( TSMSProfile(lvMain.Items[AIndex].Data['0'].AsClass) );
  end;
  ACanDelete := true;
end;

procedure TfrmMain.lvMainItemClick(const Sender: TObject; const AItem: TListViewItem);
begin
  if aItem = nil then exit;
  case CurrentView of
    cvGroups: CurrentView := cvContactsInGroup;

    cvConctactsInPhone:
    begin
      if AItem.Objects.AccessoryObject.AccessoryType = TAccessoryType.Checkmark then
      begin
        AItem.Checked  := not  AItem.Checked;

        AItem.Objects.AccessoryObject.Visible := not AItem.Objects.AccessoryObject.Visible;
        AItem.Tag := integer(AItem.Objects.AccessoryObject.Visible);
      end;
    end;

    cvTextProfiles: CurrentView := cvEditTextProfile;

    cvCampaigns: CurrentView := cvEditCampaign;
    else
      Assert(false);
  end;
end;


procedure TfrmMain.lvMainUpdateObjects(const Sender: TObject; const AItem: TListViewItem);
begin
  // In order for text to be truncated properly, shorten text object
  AItem.Objects.TextObject.Width := AItem.Objects.TextObject.Width - (2 + AItem.Objects.AccessoryObject.Width);
  // Restore checked state when device is rotated.
  // When listview is resized because of rotation, accessory properties will be reset to default values
  if AItem.Objects.AccessoryObject.AccessoryType = TAccessoryType.Checkmark then
    AItem.Objects.AccessoryObject.Visible := Boolean(AItem.Tag);
end;

procedure TfrmMain.lvDetailsDblClick(Sender: TObject);
begin
  if lvDetails.Selected = nil then exit;
  lvDetails.Items.Delete(lvDetails.Selected.Index);

end;

procedure TfrmMain.lvDetailsItemClick(const Sender: TObject; const AItem: TListViewItem);
begin
  if aItem = nil then exit;
  case CurrentView of
    cvSelectGroupsOrProfiles:
    begin
      if AItem.Objects.AccessoryObject.AccessoryType = TAccessoryType.Checkmark then
      begin
        AItem.Objects.AccessoryObject.Visible := not AItem.Objects.AccessoryObject.Visible;
        AItem.Tag := integer(AItem.Objects.AccessoryObject.Visible);
      end;
    end;
  end;
end;

procedure TfrmMain.lvDetailsUpdateObjects(const Sender: TObject; const AItem: TListViewItem);
begin
  // In order for text to be truncated properly, shorten text object
  AItem.Objects.TextObject.Width := AItem.Objects.TextObject.Width - (2 + AItem.Objects.AccessoryObject.Width);
  // Restore checked state when device is rotated.
  // When listview is resized because of rotation, accessory properties will be reset to default values
  if AItem.Objects.AccessoryObject.AccessoryType = TAccessoryType.Checkmark then
    AItem.Objects.AccessoryObject.Visible := Boolean(AItem.Tag);
end;


{$endregion}


procedure TfrmMain.OnCampActionTCore(aAction: TCampaignAction; aCampaign: TCampaign; var aStop: boolean);
begin
  case aAction of
  caBeforeStart:
    begin
      TurnOnAndKeepScreen(true);
      DimScreen(true);

      aStop := false;
      CurrentView := cvLog;
      btnMenu.Visible := false;
      ShowTabsButtons(false);
      memLog.Lines.Add('_____________________________');
      AddToLog('Starting campaign "' + aCampaign.Name + '"');
    end;
  caFinished:
    begin
      if aStop then
        AddToLog('Aborted by user.')
      else
        AddToLog(Format('Campaign "%s" is complete.', [aCampaign.Name]));
      ShowTabsButtons(true);
      btnMenu.Visible := true;
      // now disable KEEP_SCREEN - so system can go sleep in some interval
      DimScreen(false);
      TurnOnAndKeepScreen(false);
    end;
  caSetAlarm:
    begin
      AddToLog(Format('Campaign "%s" has been added to the Alarm Manager on date %s.',
          [aCampaign.Name,
          DateTimeToStr(aCampaign.StartDateTime)])
          );

    end;
  end;
end;

procedure TfrmMain.OnSentSMSTCore(aCampaign: TCampaign; aProfile: TSMSProfile; aGroup: TGroup;
      const aContact: TUDContact; aResult: TSMSError);
const
  // Status: ok. Sent sms to Alexander, +380501321456'
  LOG_STR = 'Status: %s. Contact: %s, %s';
var
  vError: string;
begin
  case aResult of
    seTimeout: vError := 'Timeout';
    seUnknown: vError := 'Unknown Error';
    seSent: vError := 'Sent';
    seGenericFail: vError := 'Generic failure';
    seNoService: vError := 'Failed: no service';
    seNullPDU: vError := 'Failed: null PDU';
    seRadioOff: vError := 'Failed: radio off';
  end;

  AddToLog(Format(LOG_STR, [vError, aContact.ContactName, aContact.Phone]) );
end;


{$region 'Log actions'}

procedure TfrmMain.AddToLog(const aText: string);
begin
  memLog.Lines.Add(DateTimeToStr(Now) + '  ' + aText);
end;

{Deleting strings from beginning of list (old log strings) }
procedure ReduceLines(aList: TStrings);
const 
  LOG_MAX_LINES = 10000; // ~530 - 600 KB 
var 
  i: integer;
  vFromIndex: integer;
begin 
  if aList.Count <= LOG_MAX_LINES then exit;
  vFromIndex := aList.Count - LOG_MAX_LINES;
  aList.BeginUpdate;
  try
    for i := vFromIndex downto 0 do
      aList.Delete(i);
  finally
    aList.EndUpdate;
  end;  
end;

{Loads from Memo and append to log file}
procedure TfrmMain.AppendAndSaveLog;
var
  vList: TStringList;
  vFilePath: string;
begin
  vFilePath := TPath.GetHomePath + TPath.DirectorySeparatorChar + FILENAME_LOG;

  if fAllLogLoaded then
  begin
    ReduceLines(memLog.Lines);
    memLog.Lines.SaveToFile(vFilePath);
  end
  else
  begin
    // append new log from memo with old in file
    vList := TStringList.Create;
    try
      if FileExists(vFilePath) then
        vList.LoadFromFile(vFilePath);
        
      vList.AddStrings(memLog.Lines);
      ReduceLines(vList);
      vList.SaveToFile(vFilePath);
    finally 
      vList.Free;
    end;
  end
end;

procedure TfrmMain.btnPrevLogsClick(Sender: TObject);
var
  vList: TStringList;
  vFilePath: string;
begin
  if fAllLogLoaded then exit;
  btnPrevLogs.Visible := false;
  fAllLogLoaded := true;
  vFilePath := TPath.Combine(TPath.GetHomePath, FILENAME_LOG);
  vList := TStringList.Create;
  try
    if not FileExists(vFilePath) then exit;
    
    vList.LoadFromFile(vFilePath);
    vList.AddStrings(memLog.Lines);
    memLog.Lines.Clear;
    ReduceLines(vList);
    memLog.Lines.AddStrings(vList);
    memLog.Repaint; // fix, because sometimes it shows incorrect scrollbar height in case when Memo contained 500 lines, and was cleared and added 20 lines. 
    memLog.ScrollBy(0, memLog.ContentSize.Height);
  finally
    vList.Free;
  end;
end;

{$ENDregion}

{ THelperListView }

function THelperListView.FindCaption(const aText: string): boolean;
var
  i: Integer;
begin
  Result := false;
  for i := 0 to Items.Count - 1 do
  begin
    Result := CompareText(Items[i].Text, aText) = 0;
    if Result then
      exit;
  end;
end;

// like Group1, or TextProfile3, Campaign1
function THelperListView.GenerateNewItemName(const aBaseStr: string): string;
var
  vIndex: integer;
begin
  vIndex := Items.Count;
  repeat
    inc(vIndex);
    Result := aBaseStr + vIndex.ToString;
  until not FindCaption(Result);
end;

procedure THelperListView.Add(const aText, aDetail: string; const aMyData: TValue; aImageIndex: integer);
var
  vItem: TListViewItem;
begin
  BeginUpdate;
  try
    vItem := Items.Add;
    vItem.Text := aText;
    vItem.Detail := aDetail;

    if not aMyData.IsEmpty then
      vItem.Data['0'] := aMyData;
    vItem.ImageIndex := aImageIndex;
  finally
    EndUpdate;
  end;
end;

function THelperListView.SelectedItemDetailText: string;
begin
  Result := '';
  if ItemIndex < 0 then exit;
  Result := Items[ItemIndex].Detail;
end;

function THelperListView.SelectedItemText: string;
begin
  Result := '';
  if ItemIndex < 0 then exit;
  Result := Items[ItemIndex].Text;
end;


function THelperListView.SelectedMyData: TClass;
begin
  Result := nil;
  if ItemIndex < 0 then exit;
  Result := Items[ItemIndex].Data['0'].AsClass;
end;


procedure TfrmMain.FormResize(Sender: TObject);
var
  vWidth: Single;
begin
  vWidth := LayMainTabs.Width / 4;
  if vWidth <> btnDashboard.Width then
  begin
    LayMainTabs.BeginUpdate;
    try
      btnDashboard.Width := vWidth;
      btnCampaigns.Width := vWidth;
      btnGroups.Width := vWidth;
      btnProfiles.Width := vWidth;
    finally
      LayMainTabs.EndUpdate;
    end;
  end;
end;


{ TSpeedButton }

procedure TSpeedButton.AdjustFixedSize(const Ref: TControl);
begin
  SetAdjustType(TAdjustType.None);

end;


end.
