{Directives:
  $REPEAT_MINUTES - Will add repeat interval in minutes


}

program SMSSender3;

uses
  System.StartUpCopy,
  vkbdhelper,
  FMX.Forms,
  MainForm in 'MainForm.pas' {frmMain},
  Core in 'Core.pas',
  EditProfileFrame in 'EditProfileFrame.pas' {frameEditProfile: TFrame},
  EditCampaignFrame in 'EditCampaignFrame.pas' {FrameEditCampaign: TFrame},
  MainPageFrame in 'MainPageFrame.pas' {frameMainPage: TFrame},
  Misc in 'Misc.pas',
  Campaigns in 'Campaigns.pas',
  SettingsFile in 'SettingsFile.pas',
  Scheduler in 'Scheduler.pas',
  SendSMS in 'SendSMS.pas';

{$R *.res}


{$IFDEF RELEASE}
    {SETPEFlAGS IMAGE_FILE_RELOCS_STRIPPED or IMAGE_FILE_DEBUG_STRIPPED or
         IMAGE_FILE_LINE_NUMS_STRIPPED}
    {$WEAKLINKRTTI ON}
    {$RTTI EXPLICIT METHODS([]) FIELDS([]) PROPERTIES([])}
{$ENDIF}


begin
  Application.Initialize;
  Application.CreateForm(TfrmMain, frmMain);
  Application.Run;
end.
