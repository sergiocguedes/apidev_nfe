unit UfrmPrincipal;

{$MODE DELPHI}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, Buttons,
  Horse, Horse.BasicAuthentication, // It's necessary to use the unit
  DataSet.Serialize,
  Horse.Jhonson,
  fpjson;

type

  { TfrmPrincipal }

  TfrmPrincipal = class(TForm)
    btnStart: TBitBtn;
    btnStop: TBitBtn;
    edtPort: TEdit;
    Label1: TLabel;
    Label2: TLabel;
    procedure btnStartClick(Sender: TObject);
    procedure btnStopClick(Sender: TObject);

  private

  public
    procedure Status;
    procedure Start;
    procedure Stop;

    function DoLogin(const AUsername, APassword: string): Boolean;
  end;

var
  frmPrincipal: TfrmPrincipal;

implementation

Uses controllernfce;

{$R *.lfm}

{ TfrmPrincipal }

procedure TfrmPrincipal.btnStartClick(Sender: TObject);
begin
  Start;
  Status;
end;

procedure TfrmPrincipal.btnStopClick(Sender: TObject);
begin
  Stop;
  Status;
end;

procedure TfrmPrincipal.Status;
begin
  btnStop.Enabled := THorse.IsRunning;
  btnStart.Enabled := not THorse.IsRunning;
  edtPort.Enabled := not THorse.IsRunning;
end;

procedure TfrmPrincipal.Start;
begin


  // It's necessary to add the middleware in the Horse:
  THorse.Use(Jhonson());
 // THorse.Use(cors);

  TControllernfce.Router;

  // Need to set "HORSE_LCL" compilation directive
  THorse.Listen(StrToInt(edtPort.Text));
end;

procedure TfrmPrincipal.Stop;
begin
  THorse.StopListen;
end;

function TfrmPrincipal.DoLogin(const AUsername, APassword: string): Boolean;
begin
  // Here inside you can access your database and validate if username and password are valid
  Result :=AUsername.Equals('admin.lsisistemas') and APassword.Equals('mK=9bFJ774iT;iB-');

  //Result := AUsername.Equals('user') and APassword.Equals('password');
end;


end.

