unit MainPageFrame;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Graphics, FMX.Controls, FMX.Forms, FMX.Dialogs, FMX.StdCtrls, FMX.Controls.Presentation,
  FMX.Layouts, FMX.Ani;

type
  TProcNotify = reference to procedure(Sender: TObject);

  TframeMainPage = class(TFrame)
    Layout1: TLayout;
    btnCampaigns: TCornerButton;
    Layout2: TLayout;
    btnGroups: TCornerButton;
    Layout3: TLayout;
    btnProfiles: TCornerButton;
    procedure FrameResize(Sender: TObject);
  private
    fOnClickBtn: TProcNotify;
    procedure IntOnClick(Sender: TObject);
  public
    destructor Destroy; override;
    procedure AfterConstruction; override;

    property OnClickButton: TProcNotify read fOnClickBtn write fOnClickBtn;
  end;


var
  gFrameDash: TframeMainPage;

implementation

{$R *.fmx}

procedure TframeMainPage.AfterConstruction;
begin
  inherited;
  btnCampaigns.OnClick := IntOnClick;
  btnGroups.OnClick := IntOnClick;
  btnProfiles.OnClick := IntOnClick;
end;

destructor TframeMainPage.Destroy;
begin
  gFrameDash := nil;
  inherited;
end;

// base scale for width 320, height 460
procedure TframeMainPage.FrameResize(Sender: TObject);
var
  vScale: Single;
begin
  if Width < Height then
    vScale :=  Width / 320
  else
    vScale := Width / 533;
  BeginUpdate;
  try
    btnCampaigns.Scale.X := vScale;
    btnCampaigns.Scale.Y := vScale;
    btnGroups.Scale.X := vScale;
    btnGroups.Scale.Y := vScale;
    btnProfiles.Scale.X := vScale;
    btnProfiles.Scale.Y := vScale;

    Layout2.Width := Width * 0.5;
    Layout1.Height := Height * 0.5;

    btnCampaigns.Enabled := true;
    btnGroups.Enabled := true;
    btnProfiles.Enabled := true;
  finally
    EndUpdate;
  end;
end;

procedure TframeMainPage.IntOnClick(Sender: TObject);
begin
  if TCornerButton(Sender).Enabled = false then exit;
  TCornerButton(Sender).Enabled := false;
  if Assigned(fOnClickBtn) then
    fOnClickBtn(Sender);
end;


end.
