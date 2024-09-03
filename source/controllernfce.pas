unit controllernfce;

{$MODE DELPHI}{$H+}

interface

uses
  Classes, SysUtils, Horse, fpjson;

type

  { TControllernfce }

  TControllernfce = class
  public
    class procedure Router;
  end;

implementation

Uses UdmPrincipal, UFuncoes;

{ TControllernfce }

procedure onConsulta_chave_acesso(Req: THorseRequest; Res: THorseResponse; Next: TNextProc);
var
  dmPrincipal : TdmPrincipal;
  Json_ret  : TJSONObject;
  body :  TJSONObject;
  cnpj, chave_acesso : string;
begin

  try
    try

      body := Req.Body< TJSONObject>; // corpo da requisição
      cnpj := body.Get('cnpj','');
      chave_acesso := body.Get('chave_acesso','');

      // ler o json retornado
      dmPrincipal := TdmPrincipal.Create(nil);
      dmPrincipal.etratado := false;

      // Pega o json object do banco de dados
      // informa que tem que enviar so gera o xml e enviar em contigencia
      json_ret := dmPrincipal.Consulta_chave_acesso(cnpj, chave_acesso, apmNFCe);

      if json_ret is TJSONObject then
         Res.Send<TJSONObject>(json_ret).Status(200)
       else
        begin
           Res.Send('Erro na consulta da chave de acesso!').Status(401);
        end;

    except
      on ex: Exception do
        Res.Send(ex.Message).Status(500);
    end;

  finally
    FreeAndNil(dmPrincipal);
  end;

end;


procedure onEmitenfce(Req: THorseRequest; Res: THorseResponse; Next: TNextProc);
var
  dmPrincipal : TdmPrincipal;
  Json_ret  : TJSONObject;
  body :  TJSONObject;
  //cnpj : string;
begin
  body := Req.Body< TJSONObject>; // corpo da requisição
  try
    try
      dmPrincipal := TdmPrincipal.Create(nil);

      json_ret := dmPrincipal.onEmitirNFCe(body);

      if json_ret is TJSONObject then
        Res.Send<TJSONObject>(json_ret).Status(200)

       else
        begin
          Res.Send('Erro no envio da NFCe!').Status(401);
        end;

    except
      on ex: Exception do
        Res.Send(ex.Message).Status(500);
    end;

  finally
    dmPrincipal.Free;
  end;

end;

procedure onCancelamentoChaveAcesso(Req: THorseRequest; Res: THorseResponse; Next: TNextProc);
var
  dmPrincipal : TdmPrincipal;
  Json_ret ,body : TJSONObject;
  cnpj, motivo_cancelamento, chave : string;
begin

  try
    try

      body := Req.Body<TJSONObject>; // corpo da requisição
      cnpj := body.Get('cnpj','');
      chave := body.Get('chave','');
      motivo_cancelamento := body.Get('motivo_cancelamento','');

      // ler o json retornado
      dmPrincipal := TdmPrincipal.Create(nil);
      dmPrincipal.etratado := false;

      // Pega o json object do banco de dados
      json_ret := dmPrincipal.cancelamento_chaveacesso(chave, cnpj, motivo_cancelamento, apmNFCe);

      if json_ret.count = 0 then
        Res.Send('Erro na consulta do status do serviço!').Status(401)
       else
        begin
          Res.Send<TJSONObject>(json_ret).Status(200);
        end;

    except
      on ex: Exception do
        Res.Send(ex.Message).Status(500);
    end;

  finally
     FreeAndNil(dmPrincipal);
  end;

end;

procedure onConsultaStatusServico(Req: THorseRequest; Res: THorseResponse; Next: TNextProc);
var
  dmPrincipal : TdmPrincipal;
  Json_ret ,body : TJSONObject;
  cnpj, autorizador : string;
begin

  try
    try

      body := Req.Body<TJSONObject>; // corpo da requisição
      cnpj := body.Get('cpf_cnpj','');
      autorizador := body.Get('autorizador','');

      // ler o json retornado
      dmPrincipal := TdmPrincipal.Create(nil);
      dmPrincipal.etratado := false;

      // Pega o json object do banco de dados
      json_ret := dmPrincipal.onConsultaStatusNFe(cnpj,autorizador,apmNFCe);

      if json_ret.count = 0 then
        Res.Send('Erro na consulta do status do serviço!').Status(401)
       else
        begin
          Res.Send<TJSONObject>(json_ret).Status(200);
        end;

    except
      on ex: Exception do
        Res.Send(ex.Message).Status(500);
    end;

  finally
     FreeAndNil(dmPrincipal);
  end;

end;

class procedure TControllernfce.Router;
begin
  THorse.Post('/nfce/consulta/chaveacesso', onConsulta_chave_acesso );
  THorse.Post('/nfce/consulta/statusServico', onConsultaStatusServico );

  THorse.Post('/nfce/', onEmitenfce);

  THorse.Post('/nfce/eventos/cancelamento/chave', onCancelamentoChaveAcesso );
end;

end.

