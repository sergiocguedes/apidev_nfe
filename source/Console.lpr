program Console;

{$MODE DELPHI}{$H+}

uses
  {$IFDEF UNIX}{$IFDEF UseCThreads}
  cthreads,
  {$ENDIF}{$ENDIF}
  Horse, DataSet.Serialize,fpjson, controllernfce;

procedure GetPing(Req: THorseRequest; Res: THorseResponse);
begin
  Res.Send('Ping');
end;

begin
  THorse.Get('/ping', GetPing);

  //TControllernfce.Router;

  THorse.Listen(9000);
end.
