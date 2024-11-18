unit EditCampaignFrame;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants, 
  FMX.Types, FMX.Graphics, FMX.Controls, FMX.Forms, FMX.Dialogs, FMX.StdCtrls, FMX.ListBox, FMX.Effects,
  FMX.Edit, FMX.Controls.Presentation, FMX.Layouts, FMX.DateTimeCtrls, FMX.Objects, FMX.EditBox,
  FMX.SpinBox, Campaigns;

type
  TFrameEditCampaign = class(TFrame)
    ebCampaignName: TEdit;
    ClearEditButton1: TClearEditButton;
    GlowRed: TGlowEffect;
    lb: TListBox;
    lbiProfiles: TListBoxItem;
    lbhProfiles: TListBoxGroupHeader;
    lbhGroups: TListBoxGroupHeader;
    lbiGroups: TListBoxItem;
    lbhStartCampaign: TListBoxGroupHeader;
    lbiStartCampaign: TListBoxItem;
    DateEditStart: TDateEdit;
    TimeEditStart: TTimeEdit;
    lblGroups: TLabel;
    lblProfiles: TLabel;
    btnEditGroups: TSpeedButton;
    btnEditProfiles: TSpeedButton;
    lbhDescription: TListBoxGroupHeader;
    ListBoxItem4: TListBoxItem;
    ebDescript: TEdit;
    ClearEditButton2: TClearEditButton;
    GlowEffect1: TGlowEffect;
    deRepeatDateEnd: TDateEdit;
    lbiRepeat: TListBoxItem;
    lbhRepeat: TListBoxGroupHeader;
    lblNextRepeat: TLabel;
    cbRepeat: TComboBox;
    sbRepeatNum: TSpinBox;
    lblHoursDays: TLabel;
    lblEvery: TLabel;
    cbExpires: TComboBox;
    teRepeatTimeEnd: TTimeEdit;
    procedure btnEditProfilesClick(Sender: TObject);
    procedure btnEditGroupsClick(Sender: TObject);
    procedure FrameResize(Sender: TObject);
    procedure cbRepeatChange(Sender: TObject);
    procedure sbRepeatNumChange(Sender: TObject);
    procedure cbExpiresChange(Sender: TObject);
  private
    fEditEvent: TNotifyEvent;
    function GetRepeatCase: TRepeatCase;
    procedure SetRepeatCase(const Value: TRepeatCase);
  public
    procedure ResetForm;
    function CanClose: boolean;
    function GetDateTimeStart: TDateTime;
    function GetDateTimeEnd: TDateTime;
    property OnPressedEditButton: TNotifyEvent read fEditEvent write fEditEvent;
    property RepeatCase: TRepeatCase read GetRepeatCase write SetRepeatCase;
  end;

var
  gEditCampaignFrame: TFrameEditCampaign;

implementation

uses
  DateUtils;

{$R *.fmx}

{ TFrameEditCampaign }

procedure TFrameEditCampaign.btnEditGroupsClick(Sender: TObject);
begin
  btnEditGroups.StaysPressed := true;  // use it like a flag, unpress it in mainForm unit when processed
  if Assigned(fEditEvent) then
    fEditEvent(Sender);
end;

procedure TFrameEditCampaign.btnEditProfilesClick(Sender: TObject);
begin
  btnEditProfiles.StaysPressed := true;
  if Assigned(fEditEvent) then
    fEditEvent(Sender);
end;

function TFrameEditCampaign.CanClose: boolean;
begin
  Result := true;
{  if lblProfiles.Text = '' then
  begin
    GlowRed.Parent := lbiProfiles;
    GlowRed.Enabled := true;
    exit(false);
  end
  else
    if lblGroups.Text = '' then
    begin
      GlowRed.Parent := lbiGroups;
      GlowRed.Enabled := true;
      exit(false);
    end
  else    }
    begin
      if GetDateTimeEnd <> 0 then
        Result := GetDateTimeStart < GetDateTimeEnd;
      if not Result then
        ShowMessage('The End date must be greater than the Start date.');
    end;
end;

procedure TFrameEditCampaign.FrameResize(Sender: TObject);
begin
  sbRepeatNum.Position.Y := cbRepeat.Position.Y;
  sbRepeatNum.Position.X := cbRepeat.Position.X + cbRepeat.Width + 20;

end;

function TFrameEditCampaign.GetDateTimeEnd: TDateTime;
begin
  if cbExpires.ItemIndex = 1 then // till date
    Result := Trunc(deRepeatDateEnd.Date) + Frac(teRepeatTimeEnd.Time)
  else
    Result := 0;
end;

function TFrameEditCampaign.GetDateTimeStart: TDateTime;
begin
  Result := Trunc(DateEditStart.Date) + Frac(TimeEditStart.Time);
end;

function TFrameEditCampaign.GetRepeatCase: TRepeatCase;
begin
  case cbRepeat.ItemIndex of
    1: Result := rcHours;
    2: Result := rcDays;
    3: Result := rcWeeks;
    4: Result := rcMonths;
    5: Result := rcYears;
    6: Result := rcMinutes;
    else
      Result := rcNone;
  end;
end;

procedure TFrameEditCampaign.SetRepeatCase(const Value: TRepeatCase);
begin
  case Value of
    rcNone: cbRepeat.ItemIndex := 0;
    rcMinutes: cbRepeat.ItemIndex := 6;
    rcHours: cbRepeat.ItemIndex := 1 ;
    rcDays: cbRepeat.ItemIndex := 2;
    rcWeeks: cbRepeat.ItemIndex := 3;
    rcMonths: cbRepeat.ItemIndex := 4;
    rcYears: cbRepeat.ItemIndex := 5;
  end;
end;

procedure TFrameEditCampaign.cbRepeatChange(Sender: TObject);
var
  vShow: boolean;
begin
  vShow := cbRepeat.ItemIndex > 0;
  sbRepeatNum.Visible := vShow;
  cbExpires.Visible := vShow;
  lblNextRepeat.Visible := vShow;
  if vShow then
  begin
    sbRepeatNum.Value := 1;
    sbRepeatNumChange(nil); // if fires of prev and cur values are different
  end
  // hide end date
  else
  begin
    cbExpires.ItemIndex := 0;
    cbExpiresChange(nil);
  end;
end;

procedure TFrameEditCampaign.cbExpiresChange(Sender: TObject);
begin
  deRepeatDateEnd.Visible := cbExpires.ItemIndex > 0;
  teRepeatTimeEnd.Visible := cbExpires.ItemIndex > 0;
end;

procedure TFrameEditCampaign.sbRepeatNumChange(Sender: TObject);
var
  vRepeatDT: TDateTime;
  vSchar: string;
begin
  if cbRepeat.ItemIndex <= 0 then exit;
  vRepeatDT := CalculateNextRepeatDate(GetDateTimeStart, RepeatCase, Trunc(sbRepeatNum.Value));
  if vRepeatDT = 0 then
    lblNextRepeat.Text := ''
  else
    lblNextRepeat.Text := 'Next repeat at: ' + DateTimeToStr(vRepeatDT);

  if sbRepeatNum.Value > 1 then
    vSchar := 's'
  else
    vSchar := '';

  case cbRepeat.ItemIndex of
    1: lblHoursDays.Text := 'hour' + vSchar;
    2: lblHoursDays.Text := 'day' + vSchar;
    3: lblHoursDays.Text := 'week' + vSchar;
    4: lblHoursDays.Text := 'month' + vSchar;
    5: lblHoursDays.Text := 'year' + vSchar;
    6: lblHoursDays.Text := 'min' + vSchar;
  end;
end;
            {
function TFrameEditCampaign.GetRepeatSeconds: integer;
begin
  case cbRepeat.ItemIndex of
    1: Result := Trunc(sbRepeatNum.Value) * SecsPerHour;
    2: Result := Trunc(sbRepeatNum.Value) * SecsPerDay;
    3: Result := Trunc(sbRepeatNum.Value) * SecsPerDay * 7;

    6: Result := Trunc(sbRepeatNum.Value) * SecsPerMin;

    else
      Result := 0;
  end;
end;       }




procedure TFrameEditCampaign.ResetForm;
begin
  GlowRed.Enabled := false;
  ebDescript.Text := '';
  lblProfiles.Text := '';
  lblGroups.Text := '';
  DateEditStart.Date := Now + 1;
  TimeEditStart.Time := 0;

  // repeat section
  cbRepeat.ItemIndex := 0;
  sbRepeatNum.Value := 0;
  cbExpires.ItemIndex := 0; // combobox on change works only when cur and prev indexes are different
  deRepeatDateEnd.Date := DateEditStart.Date + 30;
  teRepeatTimeEnd.Time := 0;
  lblNextRepeat.Text := '';
  cbRepeatChange(nil);
  cbExpiresChange(nil);
  sbRepeatNumChange(nil);
  {$ifdef REPEAT_MINUTES}
  if cbRepeat.Items.Count = 6 then
    cbRepeat.Items.Add('By Min(DEBUG ONLY)');

  {$endif}
end;



end.
