unit EditProfileFrame;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants, 
  FMX.Types, FMX.Graphics, FMX.Controls, FMX.Forms, FMX.Dialogs, FMX.StdCtrls, FMX.Edit, FMX.ScrollBox,
  FMX.Memo, FMX.Controls.Presentation, FMX.DateTimeCtrls, FMX.EditBox, FMX.SpinBox, FMX.Layouts, FMX.Effects,
  FMX.ListBox;

type
  TframeEditProfile = class(TFrame)
    ebProfileName: TEdit;
    ClearEditButton1: TClearEditButton;
    GlowRed: TGlowEffect;
    ListBox1: TListBox;
    lbhDescript: TListBoxGroupHeader;
    lbhSmsText: TListBoxGroupHeader;
    lbiDescript: TListBoxItem;
    lbiSmsText: TListBoxItem;
    ebDescript: TEdit;
    ClearEditButton2: TClearEditButton;
    memText: TMemo;
    procedure memTextChangeTracking(Sender: TObject);
  private

    { Private declarations }
  public
    function CanClose: boolean;
    procedure ResetForm;
  end;

var
  gEditProfile: TframeEditProfile;

implementation

{$R *.fmx}

function TframeEditProfile.CanClose: boolean;
begin
  if ebProfileName.Text = '' then
  begin
    GlowRed.Parent := memText;
    GlowRed.Enabled := true;
    exit(false);
  end
  else
    if (memText.Lines.Count = 0) or
       ((memText.Lines.Count = 1) and (memText.Lines[0] = '')) then
    begin
      GlowRed.Parent := memText;
      GlowRed.Enabled := true;
      exit(false);
    end;

  Result := true;
end;

procedure TframeEditProfile.memTextChangeTracking(Sender: TObject);
const
  Offset = 4; //The diference between ContentBounds and ContentLayout
var
  vNewHeight: Extended;
begin
  vNewHeight := Round(memText.ContentBounds.Height + Offset + memText.Margins.Top +
      memText.Margins.Bottom) + 3;
  if vNewHeight > 100 then
    if lbiSmsText.Height <> vNewHeight then
      lbiSmsText.Height := vNewHeight;
end;

procedure TframeEditProfile.ResetForm;
begin
  ebProfileName.Text := '';
  ebDescript.Text := '';
  memText.Lines.Clear;
  GlowRed.Enabled := false;
end;


end.
