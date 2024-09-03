unit UdmPrincipal;

{$MODE DELPHI}{$H+}

interface

uses
  Classes, SysUtils, ACBrNFe, ACBrNFCeDANFeFPDF, ACBrNFSeX,
  ACBrNFSeXDANFSeFPDFClass, ACBrNFeDANFeFPDF, ZConnection, ZDataset,
  Horse.Jhonson, fpjson, UFuncoes, pcnConversaoNFe, ACBrDFeUtil, ACBrUtil.Math,
  pcnConversao, ACBrUtil.Strings, ACBrUtil.Base,
   ACBrDFeSSL, variants, blcksock, IniFiles,
  ACBrNFSeXConfiguracoes,
  DateUtils;

type

  { TdmPrincipal }

  TdmPrincipal = class(TDataModule)
    ACBrNFCeDANFeFPDF1: TACBrNFCeDANFeFPDF;
    ACBrNFe: TACBrNFe;
    ACBrNFeDANFeFPDF1: TACBrNFeDANFeFPDF;
    ACBrNFSeX1: TACBrNFSeX;
    ACBrNFSeXDANFSeFPDF1: TACBrNFSeXDANFSeFPDF;
    Conn: TZConnection;
    mmItensNota: TZMemTable;
    mmPag: TZMemTable;
    mmEmpresa: TZMemTable;
    mmNotas: TZMemTable;
    mmEvento: TZMemTable;
  private
    caminho_respostas: string;
  public
    etratado: Boolean;
    eventos: Boolean;

    function Confirma_autorizacao(id_cliente_local: integer;
      data_autorizacao: Tdatetime; digestvalue, protocolo: string): TJSONObject;
    function Corpo_negacao_nfce(codigo_retorno, id_cliente_local: integer;
      chave_de_acesso: string): TJSONObject;
    function Corpo_autorizacao(id_cliente_local: integer;
      tpAmb: TpcnTipoAmbiente; data_emissao: Tdatetime;
      chave_acesso, nome_cliente, digestvalue, protocolo, recibo,
      cpf_identificado, caminho_xml_autorizado: string;
      total_nf, total_produtos, total_servicos, valor_icms, valor_iss: Currency;
      contigencia: Boolean): TJSONObject;

    procedure preenche_Dataset_xml(xml: string);


    function conecta_banco(): Boolean;
    function Retorna_Configuracao_NFe(cnpj: string;
      ModeloDF: TApiModeloDF): Boolean;
    function onConsultaStatusNFe(cnpj, autorizador: string;
      modelo: TApiModeloDF): TJSONObject;
    function onConsultaUltimoNumeroSerie(cnpj, serie: string;
      modelo: TApiModeloDF): TJSONObject;

    function onConsulta_id_cliente_local(chave_acesso, cnpj: string;
      modelo: TApiModeloDF): TJSONObject;

    function onEmitirNFCe(JsonRaiz: TJSONObject): TJSONObject;

    function gera_xml(JsonRaiz: TJSONObject; modelo: TApiModeloDF;
      contigencia: boolean): TJSONObject;
    procedure gera_xml_adicoes_item(JsonDI: TJSONArray);

    function Consulta_chave_acesso(cnpj, chave_acesso: string;
      modelo: TApiModeloDF): TJSONObject;

    function cancelamento_chaveacesso(chave, cnpj, motivo: string;
      modelo: TApiModeloDF): TJSONObject;

    function cancelamento_id(id_cliente_local: integer; motivo: string;
      modelo: TApiModeloDF): TJSONObject;

    function onExporta_XML(JsonRaiz: TJSONObject;  modelo: TApiModeloDF): TJSONObject;

    function cadastra_empresa(JsonRaiz: TJSONObject): TJSONObject;
    function atualiza_fiscal(JsonRaiz: TJSONObject): TJSONObject;

    procedure Libera_query_memoria(query : tzquery);

    //function GetJsonValue(const jsonValue: TJSONData ) : Variant;

  end;

var
  dmPrincipal: TdmPrincipal;

implementation

{$R *.lfm}

{ TdmPrincipal }

function TdmPrincipal.Confirma_autorizacao(id_cliente_local: integer;
  data_autorizacao: Tdatetime; digestvalue, protocolo: string): TJSONObject;
var
  LJSONObject: TJSONObject;
  qryCadNota: TZQuery;
begin

  try
    try

      qryCadNota := TZQuery.Create(nil);
      qryCadNota.Connection := Conn;
      qryCadNota.sql.Clear;
      qryCadNota.sql.Add('select * from notas where id=:id');
      qryCadNota.Params[0].AsInteger := id_cliente_local;
      qryCadNota.open;

      if qryCadNota.IsEmpty then
      begin
        LJSONObject := TJSONObject.Create;
        // Erro interno 998 da api, vai retornar 500
        LJSONObject.Add('Status', '500');
        LJSONObject.Add('xMotivo', 'Nota não encontrada na base de dados!');

        result := LJSONObject;
        exit;
      end;

      qryCadNota.edit;
      qryCadNota.FieldByName('data_emissao').AsDateTime := data_autorizacao;
      qryCadNota.FieldByName('digestvalue').AsString := digestvalue;
      qryCadNota.FieldByName('numero_protocolo').AsString := protocolo;
      qryCadNota.FieldByName('id_status').AsInteger := 1; // AUTORIZADO
      qryCadNota.FieldByName('data_autorizacao').AsDateTime := now;

      qryCadNota.Post;

      LJSONObject := TJSONObject.Create;
      LJSONObject.Add('Status', 100);
      LJSONObject.Add('xMotivo', 'autalizado com sucesso');

      result := LJSONObject;

    except
      on ex: Exception do
      begin
        LJSONObject := TJSONObject.Create;
        LJSONObject.Add('Status', 500);
        LJSONObject.Add('xMotivo', ex.Message);

        result := LJSONObject;
      end;

    end;

  finally
    qryCadNota.Free;
  end;
end;

function TdmPrincipal.Corpo_negacao_nfce(codigo_retorno,
  id_cliente_local: integer; chave_de_acesso: string): TJSONObject;
var
  statussefaz: integer;
  LJSONObject: TJSONObject;
  retorno: Boolean;
  xMotivo, protocolo, recibo, chNFe: string;
  qryCadNota: TZQuery;
begin
  xMotivo := '';
  retorno := false;
  try

    try
      qryCadNota := TZQuery.Create(nil);
      qryCadNota.Connection := Conn;
      qryCadNota.sql.Clear;
      qryCadNota.sql.Add('select * from notas where id=:id');
      qryCadNota.Params[0].AsInteger := id_cliente_local;
      qryCadNota.open;

      if qryCadNota.IsEmpty then
      begin
        LJSONObject := TJSONObject.Create;
        LJSONObject.Add('Status', 500);

        LJSONObject.Add('xMotivo', 'Nota não encontrada na base de dados!');
        result := LJSONObject;
        exit;
      end;

      // Rejeição: Duplicidade de NF-e  - consulta antes de rejeitar
      if codigo_retorno = 204 then
      begin
        ACBrNFe.WebServices.Consulta.NFeChave := chave_de_acesso;
        ACBrNFe.WebServices.Consulta.Executar;

        statussefaz := ACBrNFe.WebServices.Consulta.cStat;
        if RetornoStatusEnvio(statussefaz) then
        begin
          // se o componente não gera o xml autorizado, gera na mão
          xMotivo := ACBrNFe.WebServices.Consulta.xMotivo;
          protocolo := ACBrNFe.WebServices.Consulta.protocolo;
          recibo := ACBrNFe.WebServices.retorno.recibo;
          chNFe := ACBrNFe.WebServices.Consulta.protNFe.chNFe;

          retorno := true;
        end
        else
        begin
          xMotivo := 'Rejeição: Duplicidade de NF-e';
          retorno := false;
        end;

      end;

      // se de erro de uso denegado
      if (statussefaz = 110) or (statussefaz = 301) or (statussefaz = 302) or
        (statussefaz = 205) then
      begin
        xMotivo := 'Rejeição: Uso denegado da NF-e';
        retorno := false;
      end;

      if retorno = true then
      begin
        // se deu atualiza a tabela com a autorização

        LJSONObject := TJSONObject.Create;
        LJSONObject.Add('Status', 100);
        LJSONObject.Add('cStat', statussefaz);
        LJSONObject.Add('xMotivo', xMotivo);
        LJSONObject.Add('Protocolo', protocolo);
        LJSONObject.Add('Recibo', recibo);
        LJSONObject.Add('chNFe', chNFe);

        result := LJSONObject;
      end;

      if retorno = false then
      begin
        // se deu errado atualiza a tabela com a negação
        qryCadNota.edit;
        qryCadNota.FieldByName('id_status').AsInteger := 2; // REJEITADA
        qryCadNota.Post;

        LJSONObject := TJSONObject.Create;
        LJSONObject.Add('Status', 998); // retorno interno para informar que não resolveu
        LJSONObject.Add('cStat', statussefaz);
        LJSONObject.Add('xMotivo', xMotivo);

        result := LJSONObject;
      end;

    except
      on ex: Exception do
      begin
        LJSONObject := TJSONObject.Create;
        LJSONObject.Add('Status', 999); // retorna que deu erro de comunicação
        LJSONObject.Add('xMotivo', ex.Message);

        result := LJSONObject;
      end;

    end;

  finally
    qryCadNota.Free;
  end;
end;

function TdmPrincipal.Corpo_autorizacao(id_cliente_local: integer;
  tpAmb: TpcnTipoAmbiente; data_emissao: Tdatetime; chave_acesso, nome_cliente,
  digestvalue, protocolo, recibo, cpf_identificado,
  caminho_xml_autorizado: string; total_nf, total_produtos, total_servicos,
  valor_icms, valor_iss: Currency; contigencia: Boolean): TJSONObject;
var
  LJSONObject: TJSONObject;
  qryCadNota: TZQuery;
begin

  try
    try

      qryCadNota := TZQuery.Create(nil);
      qryCadNota.Connection := Conn;
      qryCadNota.sql.Clear;
      qryCadNota.sql.Add('select * from notas where id=:id');
      qryCadNota.Params[0].AsInteger := id_cliente_local;
      qryCadNota.open;

      qryCadNota.edit;

      if tpAmb = taProducao then
        qryCadNota.FieldByName('id_ambiente').AsInteger := 1 // PRODUCAO
      else
        qryCadNota.FieldByName('id_ambiente').AsInteger := 2; // HOMOLOGACAO

      qryCadNota.FieldByName('data_emissao').AsDateTime := data_emissao;

      qryCadNota.FieldByName('chave').AsString := chave_acesso;
      qryCadNota.FieldByName('nome_cliente').AsString := nome_cliente;

      if eventos = false then
        qryCadNota.FieldByName('eventos').AsString := 'N'
      else
        qryCadNota.FieldByName('eventos').AsString := 'S';

      qryCadNota.FieldByName('digestvalue').AsString := digestvalue;
      qryCadNota.FieldByName('numero_protocolo').AsString := protocolo;
      qryCadNota.FieldByName('recibo_autorizacao').AsString := recibo;
      qryCadNota.FieldByName('cpf_identificado').AsString := cpf_identificado;
      qryCadNota.FieldByName('total_nf').AsFloat := total_nf;
      qryCadNota.FieldByName('total_produtos').AsFloat := total_produtos;
      qryCadNota.FieldByName('total_servicos').AsFloat := total_servicos;
      qryCadNota.FieldByName('valor_icms').AsFloat := valor_icms;
      qryCadNota.FieldByName('valor_iss').AsFloat := valor_iss;

      qryCadNota.FieldByName('mes').AsInteger :=
        MonthOf(Kernel_RetornaData_servidor);
      qryCadNota.FieldByName('ano').AsFloat :=
        YearOf(Kernel_RetornaData_servidor);

      if contigencia = true then
      begin
        qryCadNota.FieldByName('tipo_emissao_id').AsInteger := 2;
        qryCadNota.FieldByName('id_status').AsInteger := 5; // CONTIGENCIA
      end
      else
      begin
        qryCadNota.FieldByName('tipo_emissao_id').AsInteger := 1;
        qryCadNota.FieldByName('id_status').AsInteger := 1; // AUTORIZADO
        qryCadNota.FieldByName('data_autorizacao').AsDateTime := now;
      end;

      qryCadNota.FieldByName('caminho_xml_autorizado').AsString :=
        caminho_xml_autorizado;

      qryCadNota.Post;

      LJSONObject := TJSONObject.Create;
      LJSONObject.Add('Status', 100);
      LJSONObject.Add('xMotivo', 'autalizado com sucesso');

      result := LJSONObject;

    except
      on ex: Exception do
      begin
        LJSONObject := TJSONObject.Create;
        LJSONObject.Add('Status', 500);
        LJSONObject.Add('xMotivo', ex.Message);

        result := LJSONObject;
      end;

    end;

  finally
    qryCadNota.Free;
  end;
end;

procedure TdmPrincipal.preenche_Dataset_xml(xml: string);
var
  i, pag: integer;
  aValor: string;
  valor_recebido: Currency;
begin
  if mmItensNota.Active then
    mmItensNota.EmptyDataSet
  else
    mmItensNota.Active :=  true;

  if mmPag.Active then
    mmPag.EmptyDataSet
  else
    mmPag.Active :=  true;

  if mmNotas.Active then
    mmNotas.EmptyDataSet
  else
    mmNotas.Active :=  true;

  if mmEvento.Active then
    mmEvento.EmptyDataSet
  else
    mmEvento.Active :=  true;

  if mmEmpresa.Active then
    mmEmpresa.EmptyDataSet
  else
    mmEmpresa.Active :=  true;

  ACBrNFe.NotasFiscais.Clear;
  if FileExists(xml) then
  begin
    ACBrNFe.NotasFiscais.LoadFromFile(xml);

    mmEmpresa.Append;
    mmEmpresa.FieldByName('razao_social').AsString := ACBrNFe.NotasFiscais.Items
      [0].nfe.Emit.xNome;
    mmEmpresa.FieldByName('cnpj').AsString := ACBrNFe.NotasFiscais.Items[0]
      .nfe.Emit.CNPJCPF;
    mmEmpresa.FieldByName('inscricao_estadual').AsString :=
      ACBrNFe.NotasFiscais.Items[0].nfe.Emit.IE;
    mmEmpresa.FieldByName('email').AsString := '';
    mmEmpresa.FieldByName('fone').AsString := ACBrNFe.NotasFiscais.Items[0]
      .nfe.Emit.EnderEmit.Fone;

    mmEmpresa.FieldByName('endereco_completo').AsString :=
      CapitalizarFrases(LowerCase( ACBrNFe.NotasFiscais.Items[0].nfe.Emit.EnderEmit.xLgr)) +  ', ' +
      ACBrNFe.NotasFiscais.Items[0].nfe.Emit.EnderEmit.nro + ', ' +
      ACBrNFe.NotasFiscais.Items[0].nfe.Emit.EnderEmit.xBairro + ', ' +
      ACBrNFe.NotasFiscais.Items[0].nfe.Emit.EnderEmit.xMun + ' - ' +
      ACBrNFe.NotasFiscais.Items[0].nfe.Emit.EnderEmit.UF;

    mmEmpresa.FieldByName('inscricao_municipal').AsString :=
      ACBrNFe.NotasFiscais.Items[0].nfe.Emit.IM;
    mmEmpresa.Post;

    // fim dados da empresa

    valor_recebido := ACBrNFe.NotasFiscais.Items[0].nfe.Total.ICMSTot.vNF +
      ACBrNFe.NotasFiscais.Items[0].nfe.pag.vTroco;

    mmNotas.Append;
    mmNotas.FieldByName('valor_produtos').AsFloat := ACBrNFe.NotasFiscais.Items
      [0].nfe.Total.ICMSTot.vProd;
    mmNotas.FieldByName('valor_servicos').AsFloat := ACBrNFe.NotasFiscais.Items
      [0].nfe.Total.ISSQNtot.vServ;
    mmNotas.FieldByName('valor_acrescimos').AsFloat :=
      ACBrNFe.NotasFiscais.Items[0].nfe.Total.ICMSTot.vOutro;
    mmNotas.FieldByName('valor_desconto').AsFloat := ACBrNFe.NotasFiscais.Items
      [0].nfe.Total.ICMSTot.vDesc;

    mmNotas.FieldByName('valor_total').AsFloat := ACBrNFe.NotasFiscais.Items[0]
      .nfe.Total.ICMSTot.vNF;
    mmNotas.FieldByName('valor_recebido').AsFloat := valor_recebido;
    mmNotas.FieldByName('valor_troco').AsFloat := ACBrNFe.NotasFiscais.Items[0]
      .nfe.pag.vTroco;
    mmNotas.FieldByName('total_tributos').AsFloat := ACBrNFe.NotasFiscais.Items
      [0].nfe.Total.ICMSTot.vTotTrib;
    mmNotas.FieldByName('nome_cliente').AsString := ACBrNFe.NotasFiscais.Items
      [0].nfe.Dest.xNome;
    mmNotas.FieldByName('numero').AsInteger := ACBrNFe.NotasFiscais.Items[0]
      .nfe.Ide.nNF;

     mmNotas.FieldByName('serie').AsInteger := ACBrNFe.NotasFiscais.Items[0]
      .nfe.Ide.serie;

    mmNotas.FieldByName('data_emissao').AsDateTime := ACBrNFe.NotasFiscais.Items
      [0].nfe.Ide.dEmi;

    mmNotas.FieldByName('cpf_idenfificado').AsString :=
      ACBrNFe.NotasFiscais.Items[0].nfe.Dest.CNPJCPF;

    for i := 0 to ACBrNFe.NotasFiscais.Items[0].nfe.Det.Count - 1 do
    begin
      mmItensNota.Append;

      aValor := FloatToStr(ACBrNFe.NotasFiscais.Items[0].nfe.Det[i].Prod.qCom);

      while pos('.', aValor) > 0 do
        aValor[pos('.', aValor)] := ',';

      mmItensNota.FieldByName('nome_produto').AsString :=
        ACBrNFe.NotasFiscais.Items[0].nfe.Det[i].Prod.xProd;
      mmItensNota.FieldByName('referencia').AsString :=
        ACBrNFe.NotasFiscais.Items[0].nfe.Det[i].Prod.cProd;
      mmItensNota.FieldByName('un').AsString := ACBrNFe.NotasFiscais.Items[0]
        .nfe.Det[i].Prod.uCom;
      mmItensNota.FieldByName('qtd').AsFloat :=
        RoundABNT(StrToFloat(aValor), 4);
      mmItensNota.FieldByName('preco_venda').AsFloat :=
        ACBrNFe.NotasFiscais.Items[0].nfe.Det[i].Prod.vUnCom;

      mmItensNota.FieldByName('desconto').AsFloat :=
        ACBrNFe.NotasFiscais.Items[0].nfe.Det[i].Prod.vDesc;

      mmItensNota.FieldByName('valor_total').AsFloat :=
        (mmItensNota.FieldByName('preco_venda').AsFloat * mmItensNota.FieldByName('qtd').AsFloat) -
        mmItensNota.FieldByName('desconto').AsFloat;

      mmItensNota.Post;
    end;

    mmNotas.FieldByName('qtditens').AsInteger := ACBrNFe.NotasFiscais.Items[0]
      .nfe.Det.Count;
    mmNotas.Post;

    for pag := 0 to ACBrNFe.NotasFiscais.Items[0].nfe.pag.Count - 1 do
    begin
      mmPag.Append();

      mmPag.FieldByName('valor').AsFloat := ACBrNFe.NotasFiscais.Items[0]
        .nfe.pag.Items[pag].vPag;
      mmPag.FieldByName('descricao').AsString := Retorna_FormaPagamento_string
        (ACBrNFe.NotasFiscais.Items[0].nfe.pag.Items[pag].tPag);

      // valor total das parcelas
      mmPag.Post;
    end;

  end;

end;

function TdmPrincipal.conecta_banco(): Boolean;
var
  ini: TIniFile;
  arq , IniDir1 : string;
  conexao1: TZConnection;
begin
  try
    result := false;
    // Caminho do INI...
    IniDir1 := GetCurrentDir + '/' + 'conexao.txt';
    //IniDir1 := '/home/sergiocguedes/projetos/' + 'conexao.txt';

    // Validar arquivo INI...

    TRY
      if NOT FileExists(IniDir1) then
        raise Exception.Create('Arquivo INI não encontrado: ' + IniDir1);

      // Instanciar arquivo INI...
      ini := TIniFile.Create(IniDir1);
      // Conn.DriverName := ini.ReadString('Banco_clickweb', 'DriverID', '');

      // Buscar dados do arquivo fisico...
      Conn.Database :=  ini.ReadString('GESTOR', 'BANCO', '');
      Conn.Password := ini.ReadString('GESTOR', 'SENHA', '');
      Conn.User := ini.ReadString('GESTOR', 'USUARIO', '');
      Conn.HostName :=  ini.ReadString('GESTOR', 'SERVIDOR', '');
      Conn.Protocol :=  'mariadb';
      Conn.Port := ini.ReadInteger('GESTOR', 'Port', 3306);
      Conn.Connected := true;

      result := true;

    except
      result := false;
    END;

  finally
    if Assigned(ini) then
      ini.Free;
  end;
end;

function TdmPrincipal.Retorna_Configuracao_NFe(cnpj: string;
  ModeloDF: TApiModeloDF): Boolean;
var
  qryLstParametroNFe, qryconfig: TZQuery;
  caminho_config, caminho_logo: string;
  Ok: Boolean;
  id_empresa: integer;
begin
  try
    qryconfig := TZQuery.Create(nil);
    qryconfig.Connection := Conn;

    qryconfig.close;
    qryconfig.sql.Clear;
    qryconfig.sql.Add('select * from config');
    qryconfig.open;

    caminho_respostas := qryconfig.FieldByName('diretorio_respostas').AsString;
    caminho_config := qryconfig.FieldByName('diretorio_app').AsString;

    qryLstParametroNFe := TZQuery.Create(nil);
    qryLstParametroNFe.Connection := Conn;
    qryLstParametroNFe.close;
    qryLstParametroNFe.sql.Clear;
    qryLstParametroNFe.sql.Add
      ('select * from empresa where cpf_cnpj=:cpf_cnpj');
    qryLstParametroNFe.ParamByName('cpf_cnpj').AsString := cnpj;
    qryLstParametroNFe.open;

    if not qryLstParametroNFe.IsEmpty then
    begin
      id_empresa := qryLstParametroNFe.FieldByName('id').AsInteger;
      caminho_logo := qryLstParametroNFe.FieldByName('logo').AsString;

      if ModeloDF = apmNFe then
        ACBrNFe.Configuracoes.Geral.ModeloDF := moNFe
       else
       ACBrNFe.Configuracoes.Geral.ModeloDF := moNFCe;

      ACBrNFe.Configuracoes.Certificados.ArquivoPFX := caminho_config + 'certificados/'+  id_empresa.ToString +'/'+
        qryLstParametroNFe.FieldByName('certificado_digital').AsString;

      ACBrNFe.Configuracoes.Geral.ForcarGerarTagRejeicao938 := fgtNunca;

      ACBrNFe.Configuracoes.Certificados.Senha := qryLstParametroNFe.FieldByName
        ('senha_certificado').AsString;
      ACBrNFe.Configuracoes.WebServices.Salvar := false;

      if EstaVazio(ACBrNFe.Configuracoes.Certificados.ArquivoPFX) then
      begin
        result := false;

        if not FileExists(ACBrNFe.Configuracoes.Certificados.ArquivoPFX) then
        begin
          result := false;
          Raise Exception.Create
            ('Caminho do Certificado Digital não especificado !');
        end;

      end;

      ACBrNFe.Configuracoes.Geral.SSLCryptLib := cryOpenSSL;
      ACBrNFe.Configuracoes.Geral.SSLHttpLib := httpOpenSSL;
      ACBrNFe.Configuracoes.Geral.SSLLib := libOpenSSL;
      ACBrNFe.Configuracoes.Geral.SSLXmlSignLib := xsLibXml2;

      ACBrNFe.SSL.SSLType := LT_TLSv1_2;
      ACBrNFe.Configuracoes.Geral.VersaoDF := ve400;

      ACBrNFe.Configuracoes.Geral.Salvar := true;

      ACBrNFe.Configuracoes.Arquivos.PathSalvar := caminho_respostas;
      //ACBrNFe.Configuracoes.Arquivos.PathInu :=

      // Configuração de tempo de espera webservice
      // ACBrNFe.Configuracoes.WebServices.AguardarConsultaRet :=
      // qryLstParametroNFeAGUARDARCONST_RETNFE.AsInteger * 1000;
      //
      // ACBrNFe.Configuracoes.WebServices.TimeOut :=
      // qryLstParametroNFeTIMEOUT_NFE.AsInteger * 1000;
      //
      // ACBrNFe.Configuracoes.WebServices.IntervaloTentativas :=
      // qryLstParametroNFeINTERVALO_TENTATIVA_NFE.AsInteger * 1000;

      ACBrNFe.Configuracoes.Arquivos.PathSchemas := caminho_config +
        'Schemas/NFe/';

      ACBrNFe.Configuracoes.WebServices.UF := qryLstParametroNFe.FieldByName
        ('UF').AsString;
      ACBrNFe.Configuracoes.WebServices.ambiente :=
        StrToTpAmb(Ok, IntToStr(qryLstParametroNFe.FieldByName('id_ambiente')
        .AsInteger));
      ACBrNFe.Configuracoes.WebServices.Visualizar := false;

      if ModeloDF = apmNFe then
      begin
        {ACBrNFeDANFEFR.FastFile := caminho_config +
          '\Relatorios\DANFeNFCe5_00.fr3';
        ACBrNFe.DANFE := ACBrNFeDANFEFR;

        ACBrNFe.Configuracoes.Arquivos.PathNFe :=
          Retorna_diretorio_completo_ate_xmlpdf(caminho_respostas, id_empresa,
          taXML, ModeloDF) + '\' + Retorna_nome_pasta_xml_gerado(tp_xml_autorizado)+ '\';

        // Carrega logo do danfe NF-e
        ACBrNFeDANFEFR.Logo := caminho_logo; }

        ACBrNFe.DANFE.PathPDF := Retorna_diretorio_completo_ate_xmlpdf(caminho_respostas, id_empresa, taPDF, ModeloDF);

      end
      else // se for nfce
      begin
        {ACBrNFeDANFEFR.FastFile := caminho_config +
          '\Relatorios\DANFeNFCe5_00.fr3';
        ACBrNFe.DANFE := ACBrNFeDANFEFR;
        ACBrNFe.Configuracoes.Arquivos.PathNFe :=
          Retorna_diretorio_completo_ate_xmlpdf(caminho_respostas, id_empresa,
          taXML, apmNFCe) + '\autorizado\';

        ACBrNFeDANFEFR.Logo := caminho_logo;

        ACBrNFe.DANFE.PathPDF := Retorna_diretorio_completo_ate_xmlpdf(caminho_respostas,
          id_empresa, tapdf, apmNFCe);     }

        if ACBrNFe.Configuracoes.WebServices.ambiente = taProducao then
        begin
          ACBrNFe.Configuracoes.Geral.IdCSC := qryLstParametroNFe.FieldByName
            ('id_csc_producao').AsString;
          ACBrNFe.Configuracoes.Geral.CSC := qryLstParametroNFe.FieldByName
            ('csc_homologacao').AsString;
        end
        else
        begin
          ACBrNFe.Configuracoes.Geral.IdCSC := qryLstParametroNFe.FieldByName
            ('id_csc_homologacao').AsString;
          ACBrNFe.Configuracoes.Geral.CSC := qryLstParametroNFe.FieldByName
            ('csc_homologacao').AsString;
        end;

      end;

      ACBrNFe.Configuracoes.Arquivos.PathEvento := Retorna_diretorio_raiz_completo(caminho_respostas,
          id_empresa, apmNFCe) + 'evento';
      ACBrNFe.Configuracoes.Arquivos.PathInu := retorna_diretorio_raiz_completo(caminho_respostas,
          id_empresa, apmNFCe) + 'Inu';

      result := true;

    end
    else
    begin
      result := false;
    end;

  finally
    qryLstParametroNFe.Free;
    qryconfig.Free;
  end;
end;

function TdmPrincipal.onConsultaStatusNFe(cnpj, autorizador: string;
  modelo: TApiModeloDF): TJSONObject;
var
  retorno: Boolean;
  LJSONObject: TJSONObject;
begin

  if (cnpj = '') then
  begin
    LJSONObject := TJSONObject.Create;
    LJSONObject.Add('Status', '500');
    LJSONObject.Add('xMotivo', 'Informe o cnpj da empresa');

    result := LJSONObject;
    exit;
  end;

  if (autorizador = '') then
  begin
    LJSONObject := TJSONObject.Create;
    LJSONObject.Add('Status', '500');
    LJSONObject.Add('xMotivo', 'Informe o estado autorizador');

    result := LJSONObject;
    exit;
  end;

  try

    if not conecta_banco then
    begin
      LJSONObject := TJSONObject.Create;
      LJSONObject.Add('Status', '500');
      LJSONObject.Add('xMotivo', 'Falha de conexão com o banco de dados');

      result := LJSONObject;
      exit;
    end;

    retorno := Retorna_Configuracao_NFe(cnpj, modelo);
    if retorno = true then
    begin
      try
        ACBrNFe.WebServices.StatusServico.Executar;

        LJSONObject := TJSONObject.Create;
        LJSONObject.Add('tpAmb',
          TpAmbToStr(ACBrNFe.WebServices.StatusServico.tpAmb));
        LJSONObject.Add('verAplic',
          ACBrNFe.WebServices.StatusServico.verAplic);
        LJSONObject.Add('Status',
          IntToStr(ACBrNFe.WebServices.StatusServico.cStat));
        LJSONObject.Add('xMotivo',
          ACBrNFe.WebServices.StatusServico.xMotivo);
        LJSONObject.Add('cUF',
          IntToStr(ACBrNFe.WebServices.StatusServico.cUF));
        LJSONObject.Add('dhRecbto',
          DateTimeToStr(ACBrNFe.WebServices.StatusServico.dhRecbto));
        LJSONObject.Add('tMed',
          IntToStr(ACBrNFe.WebServices.StatusServico.TMed));
        LJSONObject.Add('dhRetorno',
          DateTimeToStr(ACBrNFe.WebServices.StatusServico.dhRetorno));
        LJSONObject.Add('xObs', ACBrNFe.WebServices.StatusServico.xObs);

        result := LJSONObject;

      except

        on ex: Exception do
        begin
          LJSONObject := TJSONObject.Create;
          LJSONObject.Add('Status', '500');
          LJSONObject.Add('xMotivo', ex.Message);

          result := LJSONObject;
        end;

      end;
    end
    else
    begin
      LJSONObject := TJSONObject.Create;
      LJSONObject.Add('Status', '500');
      LJSONObject.Add('xMotivo', 'Falha ao carregar as configurações');

      result := LJSONObject;
      exit;
    end;

  finally
    //
  end;

end;

function TdmPrincipal.onConsultaUltimoNumeroSerie(cnpj, serie: string;
  modelo: TApiModeloDF): TJSONObject;
var
  //retorno: Boolean;
  LJSONObject: TJSONObject;
  qryPesquisa, qryLstempresa_env: TZQuery;
  id_empresa: integer;
begin
  if (cnpj = '') then
  begin
    LJSONObject := TJSONObject.Create;
    LJSONObject.Add('Status', '500');
    LJSONObject.Add('xMotivo', 'Informe o cnpj da empresa');

    result := LJSONObject;
    exit;
  end;

  if (serie = '') then
  begin
    LJSONObject := TJSONObject.Create;
    LJSONObject.Add('Status', '500');
    LJSONObject.Add('xMotivo', 'Informe um número de série');

    result := LJSONObject;
    exit;
  end;

  try

    if not conecta_banco then
    begin
      LJSONObject := TJSONObject.Create;
      LJSONObject.Add('Status', '500');
      LJSONObject.Add('xMotivo', 'Falha de conexão com o banco de dados');

      result := LJSONObject;
      exit;
    end;

    qryLstempresa_env := TZQuery.Create(nil);
    qryLstempresa_env.Connection := Conn;

    qryLstempresa_env.close;
    qryLstempresa_env.sql.Clear;
    qryLstempresa_env.sql.Add('select * from empresa where cpf_cnpj=:cpf_cnpj');
    qryLstempresa_env.ParamByName('cpf_cnpj').AsString := cnpj;
    qryLstempresa_env.open;

    id_empresa := qryLstempresa_env.FieldByName('id').AsInteger;

    qryPesquisa := TZQuery.Create(nil);
    qryPesquisa.Connection := Conn;
    qryPesquisa.sql.Clear;
    qryPesquisa.sql.Add('select max(numero) as numero from notas where ' +
      ' serie =:serie and notas.id_empresa =:id_empresa order by numero desc');
    qryPesquisa.ParamByName('serie').AsString := serie;
    qryPesquisa.ParamByName('id_empresa').AsInteger := id_empresa;
    qryPesquisa.open;

    if qryPesquisa.IsEmpty then
    begin
      LJSONObject := TJSONObject.Create;
      LJSONObject.Add('Status', 100);
      LJSONObject.Add('xMotivo', 'Tabela vazia');
      LJSONObject.Add('numero', 0);

      result := LJSONObject;
      exit;
    end;

    try
      LJSONObject := TJSONObject.Create;
      LJSONObject.Add('numero',
        qryPesquisa.FieldByName('numero').AsInteger);
      LJSONObject.Add('Status', 100);
      LJSONObject.Add('xMotivo', 'Consulta realizada com sucesso');

      result := LJSONObject;

    except

      on ex: Exception do
      begin
        LJSONObject := TJSONObject.Create;
        LJSONObject.Add('Status', 500);
        LJSONObject.Add('xMotivo', ex.Message);

        result := LJSONObject;
      end;

    end;

  finally
    qryLstempresa_env.Free;
    qryPesquisa.Free;
  end;

end;

function TdmPrincipal.onConsulta_id_cliente_local(chave_acesso, cnpj: string;
  modelo: TApiModeloDF): TJSONObject;
var
  //retorno: Boolean;
  LJSONObject: TJSONObject;
  qryPesquisa, qryLstempresa_env: TZQuery;
  id_empresa: integer;
begin
  if (cnpj = '') then
  begin
    LJSONObject := TJSONObject.Create;
    LJSONObject.Add('Status', '500');
    LJSONObject.Add('xMotivo', 'Informe o cnpj da empresa');

    result := LJSONObject;
    exit;
  end;

  if (chave_acesso = '') then
  begin
    LJSONObject := TJSONObject.Create;
    LJSONObject.Add('Status', '500');
    LJSONObject.Add('xMotivo', 'Informe uma chave de acesso');

    result := LJSONObject;
    exit;
  end;

  try

    if not conecta_banco then
    begin
      LJSONObject := TJSONObject.Create;
      LJSONObject.Add('Status', '500');
      LJSONObject.Add('xMotivo', 'Falha de conexão com o banco de dados');

      result := LJSONObject;
      exit;
    end;

    qryLstempresa_env := TZQuery.Create(nil);
    qryLstempresa_env.Connection := Conn;

    qryLstempresa_env.close;
    qryLstempresa_env.sql.Clear;
    qryLstempresa_env.sql.Add('select * from empresa where cpf_cnpj=:cpf_cnpj');
    qryLstempresa_env.ParamByName('cpf_cnpj').AsString := cnpj;
    qryLstempresa_env.open;

    id_empresa := qryLstempresa_env.FieldByName('id').AsInteger;

    qryPesquisa := TZQuery.Create(nil);
    qryPesquisa.Connection := Conn;
    qryPesquisa.sql.Clear;
    qryPesquisa.sql.Add('select id from notas where chave=:chave  ' +
      ' and notas.id_empresa =:id_empresa');
    qryPesquisa.ParamByName('chave').AsString := chave_acesso;
    qryPesquisa.ParamByName('id_empresa').AsInteger := id_empresa;
    qryPesquisa.open;

    if qryPesquisa.IsEmpty then
    begin
      LJSONObject := TJSONObject.Create;
      LJSONObject.Add('Status', 100);
      LJSONObject.Add('xMotivo',
        'Chave de acesso não encontrada no servidor!');

      result := LJSONObject;
      exit;
    end;

    try
      LJSONObject := TJSONObject.Create;
      LJSONObject.Add('id_local', qryPesquisa.FieldByName('id').AsInteger);
      LJSONObject.Add('Status', 100);
      LJSONObject.Add('xMotivo', 'Consulta realizada com sucesso');

      result := LJSONObject;

    except

      on ex: Exception do
      begin
        LJSONObject := TJSONObject.Create;
        LJSONObject.Add('Status', 500);
        LJSONObject.Add('xMotivo', ex.Message);

        result := LJSONObject;
      end;

    end;

  finally
    Libera_query_memoria(qryLstempresa_env);
    Libera_query_memoria(qryPesquisa);

    //qryLstempresa_env.Free;
    //qryPesquisa.Free;
  end;

end;

function TdmPrincipal.onEmitirNFCe(JsonRaiz: TJSONObject): TJSONObject;
var
  retorno, statusenvio, contigencia: Boolean;

  LJSONObject, retorno_gera_xml, retorno_imprime_danfe, retorno_negacao,
    retorno_autorizacao: TJSONObject;

  id_cliente, id_cliente_local, statussefaz, serie, numero, cStat,
    id_empresa: integer;
  datarcbto, data_emissao: Tdatetime;
  chave_acesso, recibo, protocolo, cnpj, nome_cliente : string;
  total_nf, total_produtos, total_servicos, valor_icms, valor_iss: Double;

  jsonEmit, jsonide:  TJSONObject;

  nNF : integer;

  qryCadNota, qryLstempresa_env, qryPesquisa, qryPesqNota: TZQuery;
  tpAmb: TpcnTipoAmbiente;
  DateTimeString, digestvalue, xmotivo_xml, xmotivo_gera_danfe, link_pdf_nfce,
    cpf_identificado, caminho_nfce, caminho_gerado, descricao_evento: string;
begin
    contigencia := false;
  eventos := false;
  retorno := false;
  descricao_evento := '';

  // Access the "emit" object
  jsonEmit := JsonRaiz.Objects['emit'];
  jsonide := JsonRaiz.Objects['ide'];

  // Extract the CNPJ value
  cnpj := jsonEmit.Get('CNPJ', '');
  id_cliente := jsonide.Get('id_cliente', 0);
  nNF := jsonide.Get('nNF', 0);

   // antes de enviar a nota, verifica se ela ja tem um xml gerado
  // se tiver carrega o xml e não gera de novo
  try
    if not conecta_banco then
    begin
      LJSONObject := TJSONObject.Create;
      LJSONObject.Add('Status', '500');
      LJSONObject.Add('xMotivo', 'Falha de conexão com o banco de dados');

      result := LJSONObject;
      exit;
    end;

    // grava a venda localmente para futuras consultas
    qryCadNota := TZQuery.Create(nil);
    qryCadNota.Connection := Conn;

    qryPesquisa := TZQuery.Create(nil);
    qryPesquisa.Connection := Conn;

    qryLstempresa_env := TZQuery.Create(nil);
    qryLstempresa_env.Connection := Conn;

    qryLstempresa_env.close;
    qryLstempresa_env.sql.Clear;
    qryLstempresa_env.sql.Add('select * from empresa where cpf_cnpj=:cpf_cnpj');
    qryLstempresa_env.ParamByName('cpf_cnpj').AsString := cnpj;
    qryLstempresa_env.open;

    id_empresa := qryLstempresa_env.FieldByName('id').AsInteger;

    retorno := Retorna_Configuracao_NFe(cnpj, apmNFCe);
    if retorno = false then
    begin
      LJSONObject := TJSONObject.Create;
      LJSONObject.Add('Status', '500');
      LJSONObject.Add('xMotivo',
        'Falha em carregar as configurações do componente!');

      result := LJSONObject;
      exit;
    end;

    // informa se mesmo que a nota ja existe vai gerar o xml
    // se tiver N o parametro o sistema, tenta achar a nota que ja foi enviada ante paa reenviar, ou consultar pela chave de acesso
    qryPesqNota := TZQuery.Create(nil);
    qryPesqNota.Connection := Conn;
    qryPesqNota.sql.Clear;
    qryPesqNota.sql.Add('select * from notas where id_cliente=:id_cliente ' +
      ' and id_empresa=:id_empresa and numero=:numero ');
    qryPesqNota.ParamByName('id_cliente').AsInteger := id_cliente;
    qryPesqNota.ParamByName('id_empresa').AsInteger := id_empresa;
    qryPesqNota.ParamByName('numero').AsInteger := nNF;
    qryPesqNota.open;

    if not qryPesqNota.IsEmpty then
    begin
      chave_acesso := qryPesqNota.FieldByName('chave').AsString;

      if chave_acesso = '' then
      begin
        retorno := false;
      end
      else
      begin

        // pega o id local
        id_cliente_local := qryPesqNota.FieldByName('id').AsInteger;
        // pega a chave de acesso

        digestvalue := qryPesqNota.FieldByName('digestvalue').AsString;
        protocolo := qryPesqNota.FieldByName('numero_protocolo').AsString;
        recibo := qryPesqNota.FieldByName('recibo_autorizacao').AsString;
        cpf_identificado := qryPesqNota.FieldByName('cpf_identificado')
          .AsString;
        total_nf := qryPesqNota.FieldByName('total_nf').AsFloat;
        total_produtos := qryPesqNota.FieldByName('total_produtos').AsFloat;
        total_servicos := qryPesqNota.FieldByName('total_servicos').AsFloat;
        valor_icms := qryPesqNota.FieldByName('valor_icms').AsFloat;
        valor_iss := qryPesqNota.FieldByName('valor_iss').AsFloat;

        // se achou tenta procurar pela chave de acesso ja existente
        ACBrNFe.WebServices.Consulta.NFeChave := chave_acesso;
        ACBrNFe.WebServices.Consulta.Executar;

        statussefaz := ACBrNFe.WebServices.Consulta.cStat;
        if RetornoStatusEnvio(statussefaz) then
        begin
          protocolo := ACBrNFe.WebServices.Consulta.protocolo;
          recibo := ACBrNFe.WebServices.retorno.recibo;
          chave_acesso := ACBrNFe.WebServices.Consulta.protNFe.chNFe;

          retorno := true;
        end
        else
          retorno := false;

      end;

      // se ja existia registro mais não deu certo consulta pela chave, apaga e gera tudo de novo
      if retorno = false then
      begin
        // apaga o registro da venda e envia de novo a nfce
        qryPesqNota.close;
        qryPesqNota.sql.Clear;
        qryPesqNota.sql.Add
          ('delete from notas where id_cliente=:id_cliente and id_empresa=:id_empresa');
        qryPesqNota.ParamByName('id_cliente').AsInteger := id_cliente;
        qryPesqNota.ParamByName('id_empresa').AsInteger := id_empresa;
        qryPesqNota.ExecSQL;
      end;

     // Sleep(1000);

    end
    else // não encontrou pedido na tabela com esse id_cliente
      retorno := false;

    if retorno = false then
    begin

      // envia normal, so vai descobrir se gera em contigencia se tiver as tags
      // de contigencia no xml
      retorno_gera_xml := gera_xml(JsonRaiz, apmNFCe, false);

      ACBrNFe.NotasFiscais.Items[0].GravarXML();

      // pega o retorno da geração do xml
      cStat := retorno_gera_xml.Get('Status', 0);
      xmotivo_xml := retorno_gera_xml.Get('xMotivo', '');
      descricao_evento := retorno_gera_xml.Get('descricao_evento', '');;

      // se deu tudo certo na geração do xml
      if cStat = 100 then
      begin

        cnpj := ACBrNFe.NotasFiscais.Items[0].nfe.Emit.CNPJCPF;
        tpAmb := ACBrNFe.NotasFiscais.Items[0].nfe.Ide.tpAmb;
        data_emissao := ACBrNFe.NotasFiscais.Items[0].nfe.Ide.dEmi;
        serie := ACBrNFe.NotasFiscais.Items[0].nfe.Ide.serie;
        numero := ACBrNFe.NotasFiscais.Items[0].nfe.Ide.nNF;
        total_nf := ACBrNFe.NotasFiscais.Items[0].nfe.Total.ICMSTot.vNF;
        total_produtos := ACBrNFe.NotasFiscais.Items[0].nfe.Total.ICMSTot.vProd;
        total_servicos := ACBrNFe.NotasFiscais.Items[0].nfe.Total.ISSQNtot.vServ;
        valor_icms := ACBrNFe.NotasFiscais.Items[0].nfe.Total.ICMSTot.vICMS;
        valor_iss := ACBrNFe.NotasFiscais.Items[0].nfe.Total.ISSQNtot.vISS;
        nome_cliente := ACBrNFe.NotasFiscais.Items[0].nfe.Dest.xNome;

        if ACBrNFe.NotasFiscais.Items[0].nfe.Ide.tpEmis = teOffLine then
          contigencia := true;

        cpf_identificado := ACBrNFe.NotasFiscais.Items[0].nfe.Dest.CNPJCPF;

        retorno := false;

        try

          ACBrNFe.NotasFiscais.GerarNFe;
          digestvalue := ACBrNFe.NotasFiscais.Items[0].nfe.signature.digestvalue;

          ACBrNFe.Configuracoes.Geral.ExibirErroSchema := false;
          ACBrNFe.Configuracoes.Geral.FormatoAlerta :=
            'Campo:%DESCRICAO% - %MSG%';

          ACBrNFe.NotasFiscais.Assinar;
          ACBrNFe.NotasFiscais.Validar;

          //if contigencia then
          chave_acesso := StringReplace(ACBrNFe.NotasFiscais.Items[0]
              .nfe.infNFe.Id, 'NFe', '', [rfReplaceAll]);

          caminho_nfce := Retorna_diretorio_completo_ate_xmlpdf(caminho_respostas, id_empresa,
            taXML, apmNFCe) + '\'+ Retorna_nome_pasta_xml_gerado(tp_xml_gerado) +'\';

          // Grava em XML gerado
          ACBrNFe.NotasFiscais.Items[0].GravarXML(chave_acesso+'-nfe.xml', caminho_nfce);

        except
          on E: Exception do
          begin
            LJSONObject := TJSONObject.Create;
            LJSONObject.Add('Status', 500);
            LJSONObject.Add('xMotivo', ACBrNFe.NotasFiscais.Items[0]
              .ErroValidacao);
            LJSONObject.Add('Erro Completo',
              ACBrNFe.NotasFiscais.Items[0].ErroValidacaoCompleto);

            result := LJSONObject;
            exit;
          end;

        end;

        try

          qryCadNota.sql.Clear;
          qryCadNota.sql.Add('select * from notas where id=:id');
          qryCadNota.Params[0].AsInteger := -1;
          qryCadNota.open;

          qryCadNota.Append;
          qryCadNota.FieldByName('id_empresa').AsInteger := id_empresa;
          qryCadNota.FieldByName('id_modelo').AsInteger := 1; // nfce

          if tpAmb = taProducao then
            qryCadNota.FieldByName('id_ambiente').AsInteger := 1 // PRODUCAO
          else
            qryCadNota.FieldByName('id_ambiente').AsInteger := 2; // HOMOLOGACAO

          qryCadNota.FieldByName('id_cliente').AsInteger := id_cliente;
          qryCadNota.FieldByName('created_at').AsDateTime :=
            Kernel_RetornaData_servidor;
          qryCadNota.FieldByName('data_emissao').AsDateTime := data_emissao;
          qryCadNota.FieldByName('serie').AsInteger := serie;
          qryCadNota.FieldByName('numero').AsInteger := numero;
          qryCadNota.FieldByName('chave').AsString := chave_acesso;
          qryCadNota.FieldByName('nome_cliente').AsString := nome_cliente;

          if eventos = false then
            qryCadNota.FieldByName('eventos').AsString := 'N'
          else
          begin
            qryCadNota.FieldByName('eventos').AsString := 'S';
            qryCadNota.FieldByName('descricao_evento').AsString := descricao_evento;
          end;

          qryCadNota.FieldByName('cpf_identificado').AsString := cpf_identificado;
          qryCadNota.FieldByName('total_nf').AsFloat := total_nf;
          qryCadNota.FieldByName('total_produtos').AsFloat := total_produtos;
          qryCadNota.FieldByName('total_servicos').AsFloat := total_servicos;
          qryCadNota.FieldByName('valor_icms').AsFloat := valor_icms;
          qryCadNota.FieldByName('valor_iss').AsFloat := valor_iss;

          qryCadNota.FieldByName('mes').AsInteger :=
            MonthOf(Kernel_RetornaData_servidor);
          qryCadNota.FieldByName('ano').AsFloat :=
            YearOf(Kernel_RetornaData_servidor);

          qryCadNota.FieldByName('id_status').AsInteger := 6; // em digitação

          if contigencia = true then
          begin
            qryCadNota.FieldByName('tipo_emissao_id').AsInteger := 2;
          end
          else
          begin
            qryCadNota.FieldByName('tipo_emissao_id').AsInteger := 1;
          end;

          qryCadNota.Post;

          // cadastra os itens da nota

          qryPesquisa.close;
          qryPesquisa.sql.Clear;
          qryPesquisa.sql.Add
            ('select * from notas where id_cliente=:id_cliente and id_empresa=:id_empresa');
          qryPesquisa.ParamByName('id_cliente').AsInteger := id_cliente;
          qryPesquisa.ParamByName('id_empresa').AsInteger := id_empresa;
          qryPesquisa.open;

          id_cliente_local := qryPesquisa.FieldByName('id').AsInteger;

          // se a nota foi enviada com as tags de contigencia, nçao faz transmissão
          statusenvio := ACBrNFe.Enviar(id_cliente, false, true);

        except
          on ex: Exception do
          begin
            retorno := false;
            LJSONObject := TJSONObject.Create;
            if ACBrNFe.WebServices.Enviar.cStat <> 0 then
              LJSONObject.Add('Status', ACBrNFe.WebServices.Enviar.cStat)
             else
              LJSONObject.Add('Status', 501); // possivel erro de rejeição, validar

            LJSONObject.Add('xMotivo', ACBrNFe.WebServices.Enviar.xMotivo);
            //LJSONObject.Add('Alertas', ACBrNFe.NotasFiscais.Items[0].Alertas);

            statusenvio := false;
            result := LJSONObject;
            exit;
          end;

        end;

        // se a nota foi enviada com as tags de contigencia, não faz transmissão
        if statusenvio then
        begin

          if statussefaz = 0 then
            datarcbto := Kernel_RetornaData_servidor()
          else
            datarcbto := ACBrNFe.NotasFiscais.Items[0].nfe.procNFe.dhRecbto;

          chave_acesso := ACBrNFe.NotasFiscais.Items[0].nfe.procNFe.chNFe;
          recibo := ACBrNFe.WebServices.Enviar.recibo;

          statussefaz := ACBrNFe.WebServices.Enviar.cStat;
          xmotivo_xml := ACBrNFe.WebServices.Enviar.xMotivo;

          if RetornoStatusEnvio(statussefaz) then
          begin

            xmotivo_xml := ACBrNFe.NotasFiscais.Items[0].nfe.procNFe.xMotivo;
            protocolo := ACBrNFe.NotasFiscais.Items[0].nfe.procNFe.nProt;
            retorno := true;

          end
          else
          begin
            retorno_negacao := Corpo_negacao_nfce(statussefaz, id_cliente_local,
              chave_acesso);

            // se le tentar resolver e der certo a tentativa
            if retorno_negacao.Get('Status', 0) = 100 then
            begin
              xmotivo_xml := retorno_negacao.Get('xMotivo', '');
              protocolo := retorno_negacao.Get('Protocolo', '');

              retorno := true;
            end
            else // Não deu certo a tentativa de resolver
              retorno := false;

          end;

        end;

      end
      else // deu erro na geração do XML
      begin
        retorno := false;
        statussefaz := 500; // não chegou a ir no websebservice
      end;

    end;  // fim de se retorno for false

    // se deu erro e não conseguiu resolver
    if retorno = false then
    begin
      LJSONObject := TJSONObject.Create;
      LJSONObject.Add('Status', 100);
      if statussefaz = 0 then
        LJSONObject.Add('cStat', 502) // erro, e tenta gerar em contigencia
       else
        LJSONObject.Add('cStat', statussefaz); // mostra qual erro trouxe

      // LJSONObject.Add('nProt', ACBrNFe.NotasFiscais.Items[0].NFe.procNFe.nProt);
      if xmotivo_xml <> '' then
        LJSONObject.Add('xMotivo', xmotivo_xml)
       else
        LJSONObject.Add('xMotivo', 'Retorno vázio do webservice');

      result := LJSONObject;
      exit;
    end;

    // se deu tudo certo inserir a nota e retorna para o cliente
    if retorno = true then
    begin
      caminho_nfce := Retorna_caminho_completo_XML(caminho_respostas,
        chave_acesso, id_empresa, apmNFCe, tp_xml_autorizado);

      Corpo_autorizacao(id_cliente_local, tpAmb, data_emissao, chave_acesso,
        nome_cliente, digestvalue, protocolo, recibo, cpf_identificado,
        caminho_nfce, total_nf, total_produtos, total_servicos, valor_icms,
        valor_iss, contigencia);

      try
        //retorno_imprime_danfe := Imprime_Danfe_NFCe_fast(id_cliente_local);
        //link_pdf_nfce := retorno_imprime_danfe.GetValue<string>
         // ('link_pdf_base64', '');
      except
        link_pdf_nfce := '';
      end;

      // monta o json de retorno
      if contigencia = true then
      begin

        LJSONObject := TJSONObject.Create;
        LJSONObject.Add('Status', '100');
        LJSONObject.Add('cStat', statussefaz);
        LJSONObject.Add('codigo_cliente',
          id_cliente_local);
        LJSONObject.Add('xMotivo', 'NFC-e emitida em contigencia');
        LJSONObject.Add('nProt', '');
        LJSONObject.Add('chNFe', chave_acesso);
        LJSONObject.Add('Recibo', recibo);
        LJSONObject.Add('link_pdf_base64', link_pdf_nfce);
        DateTimeString := FormatDateTime('yyyy-mm-dd"T"hh:nn:ss', now);
        LJSONObject.Add('dhRecbto', DateTimeString);

        result := LJSONObject;
      end
      else
      begin
        // apaga o arquivo que antes tinha sido gerado sem autorização
        caminho_gerado :=  Retorna_diretorio_completo_ate_xmlpdf(caminho_respostas, id_empresa,
            taXML, apmNFCe) + '\'+ Retorna_nome_pasta_xml_gerado(tp_xml_gerado) +'\'+ chave_acesso+'-nfe.xml';

        if FileExists(caminho_gerado) then
          DeleteFile(caminho_gerado);

        LJSONObject := TJSONObject.Create;
        LJSONObject.Add('Status', 100);
        LJSONObject.Add('cStat', statussefaz);
        LJSONObject.Add('codigo_cliente',
          id_cliente_local);
        LJSONObject.Add('xMotivo', ACBrNFe.NotasFiscais.Items[0]
          .nfe.procNFe.xMotivo);
        LJSONObject.Add('nProt', protocolo);
        LJSONObject.Add('chNFe', chave_acesso);
        LJSONObject.Add('Recibo', recibo);
        LJSONObject.Add('link_pdf_base64', link_pdf_nfce);
        DateTimeString := FormatDateTime('yyyy-mm-dd"T"hh:nn:ss',
          ACBrNFe.NotasFiscais.Items[0].nfe.procNFe.dhRecbto);
        LJSONObject.Add('dhRecbto', DateTimeString);

        result := LJSONObject;
      end;

    end;

  finally
    if Assigned(qryPesqNota) then
      qryPesqNota.Free;
    if Assigned(qryPesquisa) then
      qryPesquisa.Free;
    if Assigned(qryCadNota) then
      qryCadNota.Free;
    if Assigned(qryLstempresa_env) then
      qryLstempresa_env.Free;
  end;

end;

function TdmPrincipal.gera_xml(JsonRaiz: TJSONObject; modelo: TApiModeloDF;
  contigencia: boolean): TJSONObject;
var
  //qryLstEmpresa, qryCadNota, qryCadEvento: TZQuery;

  //jsonData: TJSONData;

  jsonide, jsondest, jsonEmit: TJSONObject;

  jsonautXML, jsonNFref, jsondet, jsonPag, Jsoncobr_fat, Jsoncobr_dup,
  Jsonrastro, JsonDI, JsonVolumes, Jsondup: TJSONArray;

  json_retorno,  jsonNFref_dados, Jsoncobr,
  Jsoncobr_dup_dados, Jsoncobr_fat_dados, jsondet_Dados, jsondet_prod,
  Jsondup_Dados, Jsonrastro_dados, JsoninfRespTec, Jsontotal,
  JsonICMSTot, JsonISSQNtot, Jsontransp, Jsoncob, Jsonfat,
  Jsontransportadora, JsonVeiTransp, JsonVolumes_Dados, JsonImposto,
  JsonICMS, JsonISS, JsonIPI, JsonPIS, JsonCofins, jsonPag_Dados,
  JsonICMSUFDest, Jsonexporta: TJSONObject;

  tipo_pessoa, descricao_evento: string;
  //jsontext,

  teste : real;

  NotaFiscalVenda, i, item_rastro, item_vol, item_dup, indIEDest, item_pag: integer;

  data_emissao: Tdatetime;

  Tipo_item: TProdutoServico;
  booNfePartilha: boolean;
begin
  booNfePartilha := False;
  descricao_evento := '';
  eventos := False;
  try
    try
      // salva o json para debug

      ACBrNFe.NotasFiscais.Clear;
      with ACBrNFe.NotasFiscais.Add.nfe do
      begin
        // jsontext  :=  jsonide.ToString;
        // configura o modelo do componente para nfe
        if modelo = apmNFe then
          ACBrNFe.Configuracoes.Geral.ModeloDF := moNFe
        else
          ACBrNFe.Configuracoes.Geral.ModeloDF := moNFce;

        infNFe.Versao := 4;

        jsonide := JsonRaiz.Objects['ide'];

        // salva o json recebido para testes por enquanto
        SaveJSONToFile(GetCurrentDir + '/'+ jsonide.Get('nNF', 0).tostring + '.json', JsonRaiz);

        // pega os dados do emitente em cima pq precisa de um campo uf para usar em função
        jsonEmit := JsonRaiz.Objects['emit'];

        NotaFiscalVenda := jsonide.Get('id_cliente');

        Ide.cNF := GerarCodigoDFe(NotaFiscalVenda);
        Ide.natOp :=
          copy(Remove_Caracteres_IvalidosString(jsonide.Get('natOp')), 1, 60);

        Ide.modelo := Retorna_Modelo(modelo);
        // Série do Documento
        Ide.serie := jsonide.Get('serie');

        // Número da Nota Fiscal; // Número da Nota Fiscal);
        Ide.nNF := jsonide.Get('nNF');

        data_emissao := Kernel_RetornaDataFuso(
          formatadata_json(jsonide.Get('dhEmi')), jsonEmit.Get('UF'));

        // Data de Emissão da Nota Fiscal
        Ide.dEmi := data_emissao;
        Ide.dSaiEnt := data_emissao;

        if jsonide.Get('tpNF') = 1 then
          Ide.tpNF := tnSaida // (E-Entrada, S-Saída)
        else
          Ide.tpNF := tnEntrada;

        Ide.idDest := Retorna_Indicador_Destino(
          jsonide.Get('tpNF'));

        Ide.finNFe := Retorna_finalidade_nf(
          jsonide.Get('finNFe'));

        if modelo = apmNFe then
        begin
          // 0-Não se aplica (por exemplo, Nota Fiscal complementar ou de ajuste);
          // 1-Operação presencial; 2-Operação não presencial, pela Internet; 3-Operação não presencial, Teleatendimento; 9-Operação não presencial, outros.
          if not (Ide.finNFe in [fnComplementar, fnAjuste]) then
          begin
            Ide.indPres := Retorna_Indicador_presenca(
              jsonide.Get('indPres'));
          end
          else
            Ide.indPres := pcNao;

          Ide.tpImp := tiRetrato;

        end;

        Ide.indIntermed := Retorna_Intermediador(
          jsonide.Get('indIntermed'));

        if modelo = apmNFCe then
        begin
          Ide.tpImp := tiNFCe; // 4-DANFE NFC-e;

          ACBrNFe.Configuracoes.Geral.VersaoQRCode := veqr200;

          Ide.indPres := pcPresencial;

          // 0-Não; 1-Consumidor final;
          Ide.indFinal := cfConsumidorFinal;

          // Forma de Emissã.o da NFe (1-Normal, 2-Contigencia) }
          if ((jsonide.Get('xJust', '') <> '') or (contigencia = True)) then
          begin
            if jsonide.Get('xJust', '') <> '' then
            begin

              // 9-Contingência off-line da NFe (as demais opções de contingência são válidas também para a NFe);
              Ide.tpEmis := teOffLine;

              Ide.dhCont := Kernel_RetornaDataFuso(
                formatadata_json(jsonide.Get('dhCont', '')), jsonEmit.Get('UF', ''));
              Ide.xJust := jsonide.Get('xJust', '');
            end
            else // casos que não conseguir comunicar com a sefaz mandar gerar a nota fiscal em contigencia
            begin
              Ide.tpEmis := teContingencia;

              Ide.dhCont := Kernel_RetornaDataFuso(
                formatadata_json(jsonide.Get('dhCont', '')), jsonEmit.Get('UF', ''));
              Ide.xJust := 'Falha de comunicação com a sefaz';
            end;
          end
          else
            Ide.tpEmis := teNormal; // 1-Normal

        end
        else
          Ide.tpEmis := teNormal;

        // ShowMessage(jsonIde.Get('cUF',''));

        Ide.tpAmb := ACBrNFe.Configuracoes.WebServices.ambiente;
        // Identificação do Ambiente (1- Producao, 2-Homologação)
        Ide.verProc := '1.0.0.0'; // Versão do seu sistema
        //Ide.cUF := UFtoCUF(jsonide.Get('cUF', ''));
        Ide.cUF := jsonide.Get('cUF');
        Ide.cMunFG := jsonide.Get('cMunFG', 0);
        // Código do Município, conforme Tabela do IBGE

        // (0- a Vista, 1 -  a Prazo, 2 - outros)
        Ide.indPag := Retorna_tipo_Pagamento(
          jsonide.Get('indPag'));

        if modelo = apmNFe then
        begin

          // pega o conteudo do json array dentro do objeto ide
          jsonNFref := jsonide.Arrays['NFref']; //Get('NFref') as TJSONArray;
          if (jsonNFref <> nil) and (jsonNFref.JSONType = jtArray) then
          begin

            for i := 0 to jsonNFref.Count - 1 do
            begin
              with Ide.NFref.Add do
              begin
                //jsonNFref_dados := jsonNFref.Items[i] as TJSONObject;
                //refNFe := jsonNFref_dados.Get('refNFe', '');

                refNFe := jsonNFref.Objects[i].Get('refNFe', '');
              end;
            end;
          end;

          // qryLstRefprodutor.First;
          // while not qryLstRefprodutor.Eof do
          // begin

          // with ide.NFref.add do
          // begin
          // refNFP.cUF := StrToInt(qryLstRefprodutoridunf.AsString);
          // refNFP.AAMM := qryLstRefprodutorAAMM.AsString;
          // refNFP.CNPJCPF := qryLstRefprodutorCPF.AsString;
          // refNFP.IE := qryLstRefprodutorIE_PRODUTOR.AsString;
          // refNFP.modelo :=  qryLstRefprodutorMODELO.AsString;
          // refNFP.serie := StrToInt(qryLstRefprodutorSERIE.AsString);
          // refNFP.nNF := StrToInt(qryLstRefprodutorNNF.AsString);
          // end;

          // qryLstRefprodutor.Next;
          // end;

        end;

        jsonautXML := JsonRaiz.Arrays['autXML']; //Get('autXML') as TJSONArray;
        if (jsonautXML <> nil) and (jsonautXML.Count > 0) then
        begin
          for i := 0 to jsonautXML.Count - 1 do
          begin
            with autXML.Add do
            begin
              //jsonautXML_dados := jsonautXML.Items[i] as TJSONObject;
              //CNPJCPF := jsonautXML_dados.Get('cnpj', '');

              CNPJCPF := jsonautXML.Objects[i].Get('refNFe', '');
            end;
          end;
        end;

        // ----------------------- dados do emitente empresa ----------------------

        Emit.CNPJCPF := OnlyNumber(jsonEmit.Get('CNPJ', ''));
        // CNPJ do Emitente
        Emit.IE := OnlyNumber(jsonEmit.Get('IE', ''));
        // Inscrição Estadual do Emitente
        Emit.xNome := Remove_Caracteres_IvalidosString(
          jsonEmit.Get('xNome', ''));
        // Razao Social ou Nome do Emitente
        Emit.xFant := Remove_Caracteres_IvalidosString(
          jsonEmit.Get('xFant'));
        // Nome Fantasia do Emitente
        Emit.EnderEmit.Fone :=
          OnlyNumber(jsonEmit.Get('fone', ''));
        // Fone do Emitente somente ddd+numero
        Emit.EnderEmit.CEP := jsonEmit.Get('CEP', 0);
        // Cep do Emitente  somente numero
        Emit.EnderEmit.xLgr :=
          Remove_Caracteres_IvalidosString(jsonEmit.Get('xLgr',''));
        // Logradouro do Emitente
        Emit.EnderEmit.nro := jsonEmit.Get('nro', '');
        // Numero do Logradouro do Emitente
        Emit.EnderEmit.xCpl := '';
        // Bairro do Emitente
        Emit.EnderEmit.xBairro := jsonEmit.Get('xBairro', '');
        // Código da Cidade do Emitente (Tabela do IBGE));
        Emit.EnderEmit.cMun := StrToInt(jsonEmit.Get('cMun'));
        // Nome da Cidade do Emitente
        Emit.EnderEmit.xMun := jsonEmit.Get('xMun', '');
        // Código do Estado do Emitente (Tabela do IBGE)
        Emit.EnderEmit.UF := jsonEmit.Get('UF', '');
        // codigo do pais
        Emit.EnderEmit.cPais := jsonEmit.Get('cPais', 0);
        Emit.EnderEmit.xPais := jsonEmit.Get('xPais', '');

        Emit.IEST := '';
        Emit.IM := jsonEmit.Get('IM', '');

        Emit.CNAE := OnlyNumber(jsonEmit.Get('CNAE', ''));

        // Verifique na cidade do emissor da NFe se é permitido
        // a inclusão de serviços na NFe
        // a inclusão de serviços na NFe
        Emit.CRT := Retorna_crt_empresa(jsonEmit.Get('CRT', 0));

        // ----------------------- dados do cliente destinatario ----------------------

        jsondest := JsonRaiz.Objects['dest'];  //Get('dest') as TJSONObject;

        tipo_pessoa := jsondest.Get('Tipo_Pessoa', 'F');
        indIEDest := jsondest.Get('indIEDest', 0);

        if ACBrNFe.Configuracoes.WebServices.ambiente = taHomologacao then
        begin
          Dest.xNome :=
            'NF-E EMITIDA EM AMBIENTE DE HOMOLOGACAO - SEM VALOR FISCAL';
        end
        else // se for produção
        begin
          // Razao social ou Nome do Destinatário
          Dest.xNome := Remove_Caracteres_IvalidosString(
            jsondest.Get('xNome', ''));
        end;

        if tipo_pessoa <> 'E' then
        begin
          if tipo_pessoa = 'J' then // juridica
          begin
            // CNPJ do Destinatário
            if ACBrNFe.Configuracoes.WebServices.ambiente = taHomologacao then
              Dest.CNPJCPF := '00000000000191'
            else
              Dest.CNPJCPF := jsondest.Get('CNPJCPF', '');

            // Inscrição Estadual do Destinatário
            if indIEDest = 2 then
            begin
              // Dest.IE := 'ISENTO'; // Inscrição Estadual do Destinatário
              // Dest.IE := '';
              Dest.indIEDest := inIsento;
            end
            else if indIEDest = 3 then
            begin
              // Dest.IE := trim(qryLstClienteINSCRICAO_ESTADUAL.AsString);
              Dest.indIEDest := inNaoContribuinte;
            end
            else if indIEDest = 1 then
            begin
              Dest.IE := jsondest.Get('IE', '');
              Dest.indIEDest := inContribuinte;
            end
            else
            begin
              // Dest.IE := '';
              Dest.indIEDest := inNaoContribuinte;
            end;

            // Inscricao na SUFRAMA;
            if jsondest.Get('ISUF', '') <> '' then
              Dest.ISUF := jsondest.Get('ISUF', '');

          end
          else // se for fisica
          begin
            Dest.CNPJCPF := jsondest.Get('CNPJCPF', '');
            Dest.indIEDest := inNaoContribuinte;

            // tem esse valor quando for produtor rural
            Dest.IE := jsondest.Get('IE', '');
          end;

        end
        else
        begin
          Dest.idEstrangeiro :=
            trim(jsondest.Get('idEstrangeiro', ''));
          Dest.indIEDest := inNaoContribuinte;
        end;

        // DD +  Fone do Destinatário
        if jsondest.Get('fone', '') <> '' then
          Dest.EnderDest.Fone :=
            copy(OnlyNumber(jsondest.Get('fone', '')), 1, 10);
        // Cep do Destinatário
        Dest.EnderDest.CEP := jsondest.Get('cep', 0);
        // Logradouro do Destinatario
        Dest.EnderDest.xLgr :=
          Remove_Caracteres_IvalidosString(copy(jsondest.Get('xLgr', ''), 1, 50));
        // Numero do Logradouro do Destinatario
        Dest.EnderDest.nro := Remove_Caracteres_IvalidosString(jsondest.Get('nro', ''));
        // Complemento do Destinatario
        // Dest.EnderDest.xCpl := Remove_Caracteres_IvalidosString(copy(jsondet.Get('IE',''), 1, 50));
        // Bairro do Destinatario

        Dest.EnderDest.xBairro :=
          Remove_Caracteres_IvalidosString(jsondest.Get('xBairro', ''));

        // Código do Município do Destinatário (Tabela IBGE)
        if tipo_pessoa <> 'E' then
          Dest.EnderDest.cMun := jsondest.Get('cMun', 0)
        else
          Dest.EnderDest.cMun := 9999999;

        // Nome da Cidade do Destinatário
        if tipo_pessoa <> 'E' then
          Dest.EnderDest.xMun :=
            Remove_Caracteres_IvalidosString(jsondest.Get('xMun', ''))
        else
          Dest.EnderDest.xMun := 'EXTERIOR';

        // Sigla do Estado do Destinatário
        if tipo_pessoa <> 'E' then
          Dest.EnderDest.UF :=
            Remove_Caracteres_IvalidosString(jsondest.Get('UF', ''))
        else
          Dest.EnderDest.UF := 'EX';
        // Código do Pais do Destinatário (Tabela do BACEN)
        Dest.EnderDest.cPais := jsondest.Get('cPais', 0);
        // Nome do País do Destinatário
        Dest.EnderDest.xPais := jsondest.Get('xPais', '');

        // -----------------------itens da nota começo ----------------------
        jsondet := JsonRaiz.Arrays['det']; //Get('det') as TJSONArray;

        if (jsondet <> nil) and (jsondet.Count > 0) then
        begin
          for i := 0 to jsondet.Count - 1 do
          begin
            with Det.Add do
            begin
              jsondet_Dados := jsondet.Items[i] as TJSONObject;
              Prod.nItem := jsondet_Dados.Get('nItem', 0);

              jsondet_prod := jsondet_Dados.Objects['prod'];    //Get('prod') as TJSONObject;

              // campo que pega se um produto ou serviço
              if jsondet_prod.Get('tipo_produto', 1) = 1 then
                Tipo_item := tpProduto
              else
                Tipo_item := tpServico;

              Prod.cProd := Remove_Caracteres_IvalidosString(
                jsondet_prod.Get('cProd', '')); // Referencia

              Prod.cEAN := jsondet_prod.Get('cEAN', '');
              Prod.cEANTrib := jsondet_prod.Get('cEANTrib', '');

              Prod.xProd := jsondet_prod.Get('xProd', '');
              // Descrição do Produto
              Prod.NCM := jsondet_prod.Get('NCM', '');
              Prod.CEST := jsondet_prod.Get('CEST', '');

              // se for um produto
              if Tipo_item = tpProduto then
              begin
                { Indicador de Produção em escala relevante, conforme
                  Cláusula 23 do Convenio ICMS 52/2017: }
                Prod.indEscala :=
                  Retorna_indicador_escala(jsondet_Dados.Get('indEscala', ''));

                if Prod.indEscala = ieNaoRelevante then
                begin
                  Prod.cBenef := jsondet_Dados.Get('cBenef', '');
                  Prod.CNPJFab := jsondet_Dados.Get('CNPJFab', '');
                end;

                if jsondet_Dados.Get('xPed', '') <> '' then
                  Prod.xPed := jsondet_Dados.Get('xPed', '');

                if jsondet_Dados.Get('nItemPed', 0) > 0 then
                  Prod.nItemPed := jsondet_Dados.Get('nItemPed', '');

                // Tabela NCM disponível em  http://www.receita.fazenda.gov.br/Aliquotas/DownloadArqTIPI.htm
                Prod.EXTIPI := '';

                if jsondet_Dados.Get('vFrete', 0) > 0 then //GetValue<double>('vFrete', 0) > 0 then
                  Prod.vFrete := jsondet_Dados.Get('vFrete', 0);
                if jsondet_Dados.Get('vSeg', 0) > 0 then //GetValue<double>('vSeg', 0) > 0 then
                  Prod.vSeg := jsondet_Dados.Get('vSeg', 0) ;

                // dados de combustiveis
                if jsondet_Dados.Get('cProdANP', 0) > 0 then
                begin
                  Prod.comb.cProdANP :=
                    jsondet_Dados.Get('cProdANP', 0);
                  // Descrição do produto conforme ANP
                  Prod.comb.descANP :=
                    jsondet_Dados.Get('descANP', '');
                  Prod.comb.pGLP := 0;
                  Prod.comb.UFcons :=
                    jsondet_Dados.Get('UFcons', '');

                  Prod.comb.CODIF := jsondet_Dados.Get('CODIF', '');
                  Prod.comb.qTemp := jsondet_Dados.Get('qTemp', 0);
                  Prod.comb.UFcons :=
                    jsondet_Dados.Get('UFcons', '');

                  // Grupo de informações da CIDE
                  Prod.comb.CIDE.qBCprod :=
                    jsondet_Dados.Get('qBCprod', 0);
                  Prod.comb.CIDE.vAliqProd :=
                    jsondet_Dados.Get('vAliqProd', 0);
                  Prod.comb.CIDE.vCIDE :=
                    jsondet_Dados.Get('vCIDE', 0);
                end;

                { Prod.comb.ICMS.vBCICMS   := 0 ;
                  Prod.comb.ICMS.vICMS     := 0 ;
                  Prod.comb.ICMS.vBCICMSST := 0 ;
                  Prod.comb.ICMS.vICMSST   := 0 ;

                  Prod.comb.ICMSInter.vBCICMSSTDest := 0 ;
                  Prod.comb.ICMSInter.vICMSSTDest   := 0 ;

                  Prod.comb.ICMSCons.vBCICMSSTCons := 0 ;
                  Prod.comb.ICMSCons.vICMSSTCons   := 0 ;
                  Prod.comb.ICMSCons.UFcons        := '' ; }

                // pega o conteudo do json array dentro do objeto ide
                Jsonrastro := jsondet_Dados.Arrays['rastro']; //Get('rastro') as TJSONArray;
                if (Jsonrastro <> nil) and (Jsonrastro.Count > 0) then
                begin

                  for item_rastro := 0 to Jsonrastro.Count - 1 do
                  begin
                    //Jsonrastro_dados := Jsonrastro.Items[i] as TJSONObject;
                    with Prod.rastro.Add do
                    begin

                      /// / Campos específicos Rastreabilidade de produto
                      {nLote := Jsonrastro_dados.Get('nLote', '');
                      qLote := Jsonrastro_dados.Get('qLote', 0);
                      dFab := formatadata_json(
                        Jsonrastro.Get('dFabi', ''));
                      dVal := formatadata_json(
                        Jsonrastro.Get('dVal', '')); }

                      nLote := Jsonrastro.Objects[i].Get('nLote', '');
                      qLote := Jsonrastro.Objects[i].Get('qLote', 0);
                      dFab := formatadata_json(
                        Jsonrastro.Objects[i].Get('dFabi', ''));
                      dVal := formatadata_json(
                        Jsonrastro.Objects[i].Get('dVal', ''));
                    end;
                  end;
                end;

                { Grupo K. Detalhamento Específico de Medicamento e de matérias-primas farmacêuticas }
                if jsondet_Dados.Get('cProdANVISA', '') <> '' then
                  Prod.MEd.Add.cProdANVISA :=
                    jsondet_Dados.Get('cProdANVISA', '');

                // Campos específicos para venda de armamento
                { with Prod.arma.Add do
                  begin
                  nSerie := 0;
                  tpArma := taUsoPermitido ;
                  nCano  := 0 ;
                  descr  := '' ;
                  end; }

                // Campos específicos para venda de combustível(distribuidoras)
                { with Prod.comb do
                  begin
                  cProdANP := 0;
                  CODIF    := '';
                  qTemp    := 0;
                  UFcons   := '';

                  CIDE.qBCprod   := 0 ;
                  CIDE.vAliqProd := 0 ;
                  CIDE.vCIDE     := 0 ;

                  ICMS.vBCICMS   := 0 ;
                  ICMS.vICMS     := 0 ;
                  ICMS.vBCICMSST := 0 ;
                  ICMS.vICMSST   := 0 ;

                  ICMSInter.vBCICMSSTDest := 0 ;
                  ICMSInter.vICMSSTDest   := 0 ;

                  ICMSCons.vBCICMSSTCons := 0 ;
                  ICMSCons.vICMSSTCons   := 0 ;
                  ICMSCons.UFcons        := '' ;
                  end; }

                if tipo_pessoa = 'E' then
                  // Se for entrada e uma importação de produtos
                  if Ide.tpNF = tnEntrada then
                  begin
                    JsonDI := jsondet_Dados.Arrays['DI']; //Get('DI') as TJSONArray;
                    //gera_xml_adicoes_item(JsonDI);
                  end;

              end; // fim se for um produto

              // tags serve para produtos e serviços
              Prod.CFOP := jsondet_prod.Get('CFOP', '');
              // CFOP incidente neste Item da NF
              Prod.uCom := Remove_Caracteres_IvalidosString(
                jsondet_prod.Get('uCom', ''));
              // Unidade de Medida do Item
              Prod.qCom := jsondet_prod.Get('qCom', 0);
              // Quantidade Comercializada do Item
              Prod.vUnCom := jsondet_prod.Get('vUnCom', 0);
              // Valor Comercializado do Item

              teste := jsondet_prod.Get('vProd',0.0);

              Prod.vProd := jsondet_prod.Get('vProd', 0.0);
              // Valor Total Bruto do Item
              Prod.uTrib := Remove_Caracteres_IvalidosString(
                jsondet_prod.Get('uTrib', ''));
              // Unidade de Medida Tributável do Item
              Prod.qTrib := jsondet_prod.Get('qTrib', 0);
              // '1'; // Quantidade Tributável do Item
              Prod.vUnTrib := jsondet_prod.Get('vUnTrib', 0);
              // Valor Tributável do Item

              if jsondet_prod.Get('vOutro', 0.0) > 0 then
                Prod.vOutro := jsondet_prod.Get('vOutro', 0.0);
              // Valor outros do Item;

              if jsondet_prod.Get('vDesc', 0.0) > 0 then
                Prod.vDesc := jsondet_prod.Get('vDesc', 0.0);

              descricao_evento := jsondet_prod.Get('infAdProd', '');
              infAdProd := descricao_evento;
              // Informacoes adicionais;

              // pega o json object de todos os impostos
              JsonImposto := jsondet_Dados.Objects['imposto']; //Get('imposto') as TJSONObject;
              with Imposto do
              begin

                // PARTE DE IMPOSTOS // SE FOR PRODUTO
                if Tipo_item = tpProduto then
                begin
                  // pega o json ojbect de icms
                  JsonICMS := JsonImposto.Objects['ICMS'];//Get('ICMS') as TJSONObject;

                  ACBrNFe.NotasFiscais.Add.nfe.Det.Add.Imposto.vTotTrib := 0;

                  // Origem da Mercadoria (0-Nacional, 1-Estrangera, 2-Estrangeira adiquirida no Merc. Interno)
                  ICMS.orig :=
                    Retorna_Origem_mercadoria(JsonICMS.Get('orig', 0));

                  // Se não for simples nacional, usa CST
                  if Emit.CRT <> crtSimplesNacional then
                  begin
                    // Guarda na variavel o CST do produto
                    ICMS.CST :=
                      Retorna_CST(JsonICMS.Get('CST', ''));

                    // Cst 00
                    if ICMS.CST = cst00 then
                    begin
                      // Modalidade de determinação da BC do ICMS
                      ICMS.modbc :=
                        Retorna_ModalidadeBC(JsonICMS.Get('modbc', 0));
                      // Valor da Base de Cálculo do ICMS
                      ICMS.vBC := JsonICMS.Get('vBC', 0.0);
                      // Aliquota do imposto
                      ICMS.pICMS := JsonICMS.Get('pICMS', 0.0);
                      // Valor do ICMS em Reais
                      ICMS.vICMS := JsonICMS.Get('vICMS ', 0.0);

                      // Percentual do Fundo de Combate à Pobreza FCP)
                      ICMS.pFCP := 0;
                      // Valor do Fundo de Combate à Pobreza (FCP)
                      ACBrNFe.NotasFiscais.Add.nfe.Det.new.Imposto.
                        ICMS.vFCP := 0;
                    end;

                    // Cst 10
                    if ICMS.CST = cst10 then
                    begin
                      ICMS.modbc :=
                        Retorna_ModalidadeBC(JsonICMS.Get('modbc', 0));
                      // Modalidade de determinação da BC do ICMS
                      ICMS.vBC := JsonICMS.Get('vBC', 0.0);
                      // Valor da Base de Cálculo do ICMS
                      ICMS.pICMS := JsonICMS.Get('pICMS', 0.0);
                      // Aliquota do imposto
                      ICMS.vICMS := JsonICMS.Get('vICMS', 0.0);
                      // Valor do ICMS em Reais

                      ICMS.modBCST :=
                        Retorna_ModalidadeBCST(JsonICMS.Get('modBCST', 0)); //GetValue<integer>('modBCST', 0));

                      ICMS.pMVAST := JsonICMS.Get('pMVAST', 0.0);

                      // pRedBCST:=
                      ICMS.vBCST := JsonICMS.Get('vBCST',0.0);
                      ICMS.pICMSST := JsonICMS.Get('pICMSST', 0.0);
                      ICMS.vICMSST := JsonICMS.Get('vICMSST', 0.0);
                      // pRedBC  := cdsLstItens;

                      // Valor da Base de Cálculo do FCP
                      ICMS.vBCFCP := 0;
                      // Percentual do Fundo de Combate à Pobreza FCP)
                      ICMS.pFCP := 0;
                      // Valor do Fundo de Combate à Pobreza (FCP)
                      ICMS.vFCP := 0;

                      // Informar o valor da Base de Cálculo do FCP retido por Substituição Tributária
                      ICMS.vBCFCPST := 0;
                      // Percentual relativo ao Fundo de Combate à Pobreza (FCP) retido por substituição tributária.
                      ICMS.pFCPST := 0;
                      // Valor do ICMS relativo ao Fundo de Combate à Pobreza (FCP) retido por substituição tributária
                      ICMS.vFCPST := 0;

                    end;

                    // Cst 20
                    if ICMS.CST = cst20 then
                    begin
                      ICMS.modbc :=
                        Retorna_ModalidadeBC(JsonICMS.Get('modbc', 0));
                      // Modalidade de determinação da BC do ICMS
                      ICMS.pRedBC := JsonICMS.Get('pRedBC', 0);
                      // Percentual da REdução de BC
                      ICMS.vBC := JsonICMS.Get('vBC',0.0);
                      // Valor da Base de Cálculo do ICMS
                      ICMS.pICMS := JsonICMS.Get('pICMS', 0);

                      // Aliquota do imposto
                      ICMS.vICMS := JsonICMS.Get('vICMS ', 0.0);
                      // Valor do ICMS em Reais

                      // Valor da Base de Cálculo do FCP
                      ICMS.vBCFCP := 0;
                      // Percentual do Fundo de Combate à Pobreza FCP)
                      ICMS.pFCP := 0;
                      // Valor do Fundo de Combate à Pobreza (FCP)
                      ICMS.vFCP := 0;

                      ICMS.vICMSDeson :=
                        JsonICMS.Get('vICMSDeson', 0.0);
                      ICMS.motDesICMS :=
                        retorna_motivo_icms_desonerado(
                        JsonICMS.Get('motDesICMS', 0));
                    end;

                    // Cst 30
                    if ICMS.CST = cst30 then
                    begin
                      { cst 30 não envia o calculo do icms proprio }
                      ICMS.modBCST :=
                        Retorna_ModalidadeBCST(JsonICMS.Get('modBCST', 0)); //GetValue<integer>('modBCST', 0));
                      ICMS.pMVAST := JsonICMS.Get('pMVAST', 0);

                      ICMS.vBCST := JsonICMS.Get('vBCST', 0.0);
                      ICMS.pICMSST := JsonICMS.Get('pICMSST', 0.0);
                      ICMS.vICMSST := JsonICMS.Get('vICMSST', 0.0);

                      // Valor da Base de Cálculo do FCP
                      ICMS.vBCFCPST := 0;
                      // Percentual do Fundo de Combate à Pobreza FCP)
                      ICMS.pFCPST := 0;
                      // Valor do Fundo de Combate à Pobreza (FCP)
                      ICMS.vFCPST := 0;

                      ICMS.vICMSDeson :=
                        JsonICMS.Get('vICMSDeson', 0.0);
                      ICMS.motDesICMS :=
                        retorna_motivo_icms_desonerado(
                        JsonICMS.Get('motDesICMS', 0));
                    end;

                    // Cst 40, 41, 50
                    if ICMS.CST in [cst40, cst41, cst50] then
                    begin
                      ICMS.vICMSDeson :=
                        JsonICMS.Get('vICMSDeson', 0.0);
                      ICMS.motDesICMS :=
                        retorna_motivo_icms_desonerado(
                        JsonICMS.Get('motDesICMS', 0));
                    end;

                    // Cst 51
                    if ICMS.CST = cst51 then
                    begin
                      // Modalidade de determinação da BC do ICMS
                      ICMS.modbc :=
                        Retorna_ModalidadeBC(JsonICMS.Get('modbc', 0));
                      // Percentual da REdução de BC
                      ICMS.pRedBC := JsonICMS.Get('pRedBC', 0);
                      // Valor da Base de Cálculo do ICMS
                      ICMS.vBC := JsonICMS.Get('vBC', 0.0);
                      // Aliquota do imposto
                      ICMS.pICMS := JsonICMS.Get('pICMS', 0);

                      // icms da operação
                      ICMS.vICMSOp := JsonICMS.Get('vICMSOp', 0.0);
                      // taxa de icms deferido
                      ICMS.pdif := JsonICMS.Get('pdif', 0);
                      ;
                      // valor do icms deferido
                      ICMS.vICMSDif := JsonICMS.Get('vICMSDif', 0.0);

                      // Valor do ICMS em Reais
                      ICMS.vICMS := JsonICMS.Get('vICMS', 0.0);

                      // Valor da Base de Cálculo do FCP
                      ICMS.vBCFCP := 0;
                      // Percentual do Fundo de Combate à Pobreza FCP)
                      ICMS.pFCP := 0;
                      // Valor do Fundo de Combate à Pobreza (FCP)
                      ICMS.vFCP := 0;

                    end;

                    // Cst 60
                    if ICMS.CST = cst60 then
                    begin
                      ICMS.vBCSTRet := 0.00; // Valor da BC do ICMS ST Retido
                      ICMS.vICMSSTRet := 0.00; // Valor do ICMS ST

                      { Deve ser informada a alíquota do cálculo do ICMS-ST, já
                        incluso o FCP caso incida sobre a mercadoria. Exemplo:
                        alíquota da mercadoria na venda ao consumidor final =
                        18% e 2% de FCP. A alíquota a ser informada no campo
                        pST deve ser 20% }
                      ICMS.pST := 0;
                      // Informar o valor da Base de Cálculo do FCP retido anteriormente por ST
                      ICMS.vBCFCPSTRet := 0;
                      // Percentual relativo ao Fundo de Combate à Pobreza (FCP) retido por substituição tributária.
                      ICMS.pFCPSTRet := 0;
                      // Valor do ICMS relativo ao Fundo de Combate à Pobreza (FCP) retido por substituição tributária.
                      ICMS.vFCPSTRet := 0;

                      ICMS.vICMSSubstituto := 0;
                    end;

                    // Cst 70
                    if ICMS.CST = cst70 then
                    begin
                      // Modalidade de determinação da BC do ICMS
                      ICMS.modbc :=
                        Retorna_ModalidadeBC(JsonICMS.Get('modbc', 0));
                      // Percentual da REdução de BC
                      ICMS.pRedBC := JsonICMS.Get('pRedBC', 0);

                      // Valor da Base de Cálculo do ICMS
                      ICMS.vBC := JsonICMS.Get('vBC', 0.0);
                      // Aliquota do imposto
                      ICMS.pICMS := JsonICMS.Get('pICMS', 0);

                      // Valor do ICMS em Reais
                      ICMS.vICMS := JsonICMS.Get('vICMS', 0.0);

                      // modalidade de base de calculo st
                      ICMS.modBCST :=
                        Retorna_ModalidadeBCST(JsonICMS.Get('modBCST', 0));  //  GetValue<integer>('modBCST', 0));
                      // valor do vma margem de valor agregado
                      ICMS.pMVAST := JsonICMS.Get('pMVAST', 0);

                      // percentual de redução de base de calculo st
                      ICMS.pRedBCST := JsonICMS.Get('pRedBCST', 0);

                      ICMS.vBCST := JsonICMS.Get('vBCST', 0.0);
                      ICMS.pICMSST := JsonICMS.Get('pICMSST', 0.0);
                      ICMS.vICMSST := JsonICMS.Get('vICMSST', 0.0);

                      // Valor da Base de Cálculo do FCP
                      ICMS.vBCFCP := 0;
                      // Percentual do Fundo de Combate à Pobreza FCP)
                      ICMS.pFCP := 0;
                      // Valor do Fundo de Combate à Pobreza (FCP)
                      ICMS.vFCP := 0;

                      // Informar o valor da Base de Cálculo do FCP retido por Substituição Tributária
                      ICMS.vBCFCPST := 0;
                      // Percentual relativo ao Fundo de Combate à Pobreza (FCP) retido por substituição tributária.
                      ICMS.pFCPST := 0;
                      // Valor do ICMS relativo ao Fundo de Combate à Pobreza (FCP) retido por substituição tributária
                      ICMS.vFCPST := 0;

                      ICMS.vICMSDeson :=
                        JsonICMS.Get('vICMSDeson ', 0.0);
                      ICMS.motDesICMS :=
                        retorna_motivo_icms_desonerado(
                        JsonICMS.Get('motDesICMS', 0));

                    end;

                    // Cst 90
                    if ICMS.CST = cst90 then
                    begin
                      ICMS.modbc :=
                        Retorna_ModalidadeBC(JsonICMS.Get('modbc', 0));
                      // Modalidade de determinação da BC do ICMS
                      ICMS.pRedBC := JsonICMS.Get('pRedBC', 0);
                      // Percentual da REdução de BC
                      ICMS.vBC := JsonICMS.Get('vBC',0.0);
                      // Valor da Base de Cálculo do ICMS
                      ICMS.pICMS := JsonICMS.Get('pICMS', 0);
                      // Aliquota do imposto
                      ICMS.vICMS := JsonICMS.Get('vICMS', 0.0);
                      // Valor do ICMS em Reais

                      ICMS.modBCST :=
                        Retorna_ModalidadeBCST(JsonICMS.Get('modBCST', 0));   //GetValue<integer>('modBCST', 0));
                      ICMS.pMVAST := JsonICMS.Get('pMVAST', 0);
                      // pRedBCST:=
                      ICMS.vBCST := JsonICMS.Get('vBCST', 0.0);
                      ICMS.pICMSST := JsonICMS.Get('pICMSST :', 0);
                      ICMS.vICMSST := JsonICMS.Get('vICMSST', 0.0);

                      // Valor da Base de Cálculo do FCP
                      ICMS.vBCFCP := 0;
                      // Percentual do Fundo de Combate à Pobreza FCP)
                      ICMS.pFCP := 0;
                      // Valor do Fundo de Combate à Pobreza (FCP)
                      ICMS.vFCP := 0;

                      // Informar o valor da Base de Cálculo do FCP retido por Substituição Tributária
                      ICMS.vBCFCPST := 0;
                      // Percentual relativo ao Fundo de Combate à Pobreza (FCP) retido por substituição tributária.
                      ICMS.pFCPST := 0;
                      // Valor do ICMS relativo ao Fundo de Combate à Pobreza (FCP) retido por substituição tributária
                      ICMS.vFCPST := 0;

                      ICMS.vICMSDeson :=
                        JsonICMS.Get('vICMSDeson', 0.0);
                      ICMS.motDesICMS :=
                        retorna_motivo_icms_desonerado(
                        JsonICMS.Get('motDesICMS ', 0));

                    end;

                  end
                  else // se for simples nacional
                  begin
                    ICMS.CSOSN :=
                      Retorna_CSOSN(JsonICMS.Get('CST', ''));

                    // Cst 101
                    if ICMS.CSOSN = csosn101 then
                    begin
                      ICMS.pCredSN := JsonICMS.Get('pCredSN', 0);
                      // Aliquota Aplicavel
                      ICMS.vCredICMSSN :=
                        JsonICMS.Get('vCredICMSSN', 0);
                      // Valor crédito do ICMS que pode ser aproveitado
                    end;

                    // Cst 102, 103, 300 ou 400
                    if ((ICMS.CSOSN = csosn102) or (ICMS.CSOSN = csosn103) or
                      (ICMS.CSOSN = csosn300) or (ICMS.CSOSN = csosn400)) then
                    begin
                      // Não tem código
                    end;

                    // Cst 201
                    if ICMS.CSOSN = csosn201 then
                    begin
                      ICMS.modbc :=
                        Retorna_ModalidadeBC(JsonICMS.Get('modbc', 0));
                      // Modalidade de determinação da BC do ICMS
                      ICMS.modBCST :=
                        Retorna_ModalidadeBCST(JsonICMS.Get('modBCST', 0));
                      ICMS.pMVAST := JsonICMS.Get('pMVAST', 0);
                      // pRedBCST:=
                      ICMS.vBCST := JsonICMS.Get('vBCST', 0.0);
                      ICMS.pICMSST := JsonICMS.Get('pICMSST', 0);
                      ICMS.vICMSST := JsonICMS.Get('vICMSST', 0.0);

                      // Alíquota aplicável de cálculo do crédito SIMPLES NACIONAL).
                      ICMS.pCredSN := JsonICMS.Get('pCredSN', 0);
                      ;
                      // Aliquota Aplicavel
                      ICMS.vCredICMSSN :=
                        JsonICMS.Get('vCredICMSSN', 0.0);

                      // Valor da Base de Cálculo do FCP retido por Substituição Tributária
                      ICMS.vBCFCPST := 0;
                      // Percentual do FCP retido por Substituição Tributária
                      ICMS.pFCPST := 0;
                      // Valor do FCP retido por Substituição Tributária
                      ICMS.vFCPST := 0;
                    end;

                    // Cst 202, 203
                    if ((ICMS.CSOSN = csosn202) or (ICMS.CSOSN = csosn203)) then
                    begin
                      ICMS.modbc :=
                        Retorna_ModalidadeBC(JsonICMS.Get('modbc', 0));
                      // Modalidade de determinação da BC do ICMS
                      ICMS.modBCST :=
                        Retorna_ModalidadeBCST(JsonICMS.Get('modBCST', 0));
                      ICMS.pMVAST := JsonICMS.Get('pMVAST', 0);
                      // pRedBCST:=
                      ICMS.vBCST := JsonICMS.Get('vBCST', 0.0);
                      ICMS.pICMSST := JsonICMS.Get('pICMSST', 0);
                      ICMS.vICMSST := JsonICMS.Get('vICMSST', 0.0);
                      // Valor da Base de Cálculo do FCP retido por Substituição Tributária
                      ICMS.vBCFCPST := 0;
                      // Percentual do FCP retido por Substituição Tributária
                      ICMS.pFCPST := 0;
                      // Valor do FCP retido por Substituição Tributária
                      ICMS.vFCPST := 0;
                    end;

                    // Cst 500
                    if ICMS.CSOSN = csosn500 then
                    begin
                      ICMS.vBCSTRet := 0; // Valor da BC do ICMS ST Retido
                      ICMS.vICMSSTRet := 0; // Valor do ICMS ST
                      { Deve ser informada a alíquota do cálculo do ICMS-ST, já
                        incluso o FCP caso incida sobre a mercadoria. Exemplo:
                        alíquota da mercadoria na venda ao consumidor final =
                        18% e 2% de FCP. A alíquota a ser informada no campo
                        pST deve ser 20%. }
                      ICMS.pST := 0;

                      // Valor da Base de Cálculo do FCP retido por Substituição Tributária
                      ICMS.vBCFCPST := 0;
                      // Percentual do FCP retido por Substituição Tributária
                      ICMS.pFCPST := 0;
                      // Valor do FCP retido por Substituição Tributária
                      ICMS.vFCPST := 0;

                      ICMS.vICMSSubstituto := 0;
                    end;

                    // Cst 900
                    if ICMS.CSOSN = csosn900 then
                    begin
                      ICMS.modbc :=
                        Retorna_ModalidadeBC(JsonICMS.Get('modbc', 0));
                      // Modalidade de determinação da BC do ICMS
                      ICMS.pRedBC := JsonICMS.Get('pRedBC', 0);
                      // Percentual da REdução de BC
                      ICMS.vBC := JsonICMS.Get('vBC', 0.0);
                      // Valor da Base de Cálculo do ICMS
                      ICMS.pICMS := JsonICMS.Get('pICMS', 0);
                      // Aliquota do imposto
                      ICMS.vICMS := JsonICMS.Get('vICMS', 0.0);
                      // Valor do ICMS em Reais

                      ICMS.modBCST :=
                        Retorna_ModalidadeBCST(JsonICMS.Get('modBCST', 0));
                      ICMS.pMVAST := JsonICMS.Get('pMVAST', 0);
                      ICMS.vBCST := JsonICMS.Get('vBCST', 0.0);
                      ICMS.pICMSST := JsonICMS.Get('pICMSST', 0);
                      ICMS.vICMSST := JsonICMS.Get('vICMSST', 0.0);

                      // Valor da Base de Cálculo do FCP retido por Substituição Tributária
                      ICMS.vBCFCPST := 0;
                      // Percentual do FCP retido por Substituição Tributária
                      ICMS.pFCPST := 0;
                      // Valor do FCP retido por Substituição Tributária
                      ICMS.vFCPST := 0;

                      ICMS.pCredSN := JsonICMS.Get('pCredSN', 0);
                      // Aliquota Aplicavel
                      ICMS.vCredICMSSN :=
                        JsonICMS.Get('vCredICMSSN', 0);
                      // Valor crédito do ICMS que pode ser aproveitado
                    end;

                  end;

                  { ICMS para a UF de destino }
                  // Se a nota for pra consumidor nao contribuinte gera os campos de impostos interestaduais
                  if Dest.indIEDest = inNaoContribuinte then
                  begin
                    // Se for uma nota de saida
                    if Ide.tpNF = tnSaida then
                    begin
                      // Se for pra fora do Estado
                      if Ide.idDest = doInterestadual then
                      begin
                        booNfePartilha := True;

                        JsonICMSUFDest :=
                          JsonImposto.Objects['ICMSUFDest']; //Get('ICMSUFDest') as TJSONObject;

                        ICMSUFDest.vBCFCPUFDest :=
                          JsonICMSUFDest.Get('vBCFCPUFDest', 0.0);

                        // Base de calculo pega a mesma base do icms, verificar se precisa mudar
                        ICMSUFDest.vBCUFDest :=
                          JsonICMSUFDest.Get('vBCUFDest', 0.0);
                        // Percentual de pobreza Pegar na tabela conforme estado de destino
                        ICMSUFDest.pFCPUFDest :=
                          JsonICMSUFDest.Get('pFCPUFDest', 0);
                        // Aliquota interna de destino Pegar na tabela conforme estado de destino
                        ICMSUFDest.pICMSUFDest :=
                          JsonICMSUFDest.Get('pICMSUFDest', 0);
                        // Aliquota interestadual conforme origem e destino
                        ICMSUFDest.pICMSInter :=
                          JsonICMSUFDest.Get('pICMSInter', 0);
                        // Imcs para a uf de destino conforme o Ano
                        ICMSUFDest.pICMSInterPart :=
                          JsonICMSUFDest.Get('pICMSInterPart', 0);

                        // ICMSUFDest – Grupo de Tributaçãõo do ICMS para a UF de destino

                        // Calculo do icms da pobreza aliquota * base de calculo
                        ICMSUFDest.vFCPUFDest :=
                          JsonICMSUFDest.Get('vFCPUFDest', 0.0);

                        // Icms devido a sefaz de destino
                        ICMSUFDest.vICMSUFDest :=
                          JsonICMSUFDest.Get('vICMSUFDest', 0.0);

                        // Se a Empresa for Simples, a aliquota pro estado de Origem é 0
                        if Emit.CRT <> crtSimplesNacional then
                          ICMSUFDest.vICMSUFRemet := 0
                        else
                          ICMSUFDest.vICMSUFRemet :=
                            JsonICMSUFDest.Get('vICMSUFRemet', 0.0);
                      end;
                    end;

                  end;

                  // --------------- IPI - imposto sobre produto industrializado -------------------
                  JsonIPI := JsonImposto.Objects['IPI'];  //Get('IPI') as TJSONObject;

                  ipi.CST := Retorna_IPI(JsonIPI.Get('CST', ''));

                  ipi.clEnq := ''; // classe de enquadramento
                  ipi.CNPJProd := '';
                  // CNPJ do produtor da mercadoria quando diferente do emitente
                  ipi.cSelo := ''; // Codigo do selo de Controle IPI
                  ipi.qSelo := 0; // Quantidade de selo de Controle

                  // Se CST = "02" ou "52", informar cEnq com um valor entre "301" e "399";
                  ipi.cEnq := JsonIPI.Get('cEnq', '');
                  // Codigo de enquadramento legal do IPI;

                  if ((ipi.CST = ipi01) or (ipi.CST = ipi02) or
                    (ipi.CST = ipi03) or (ipi.CST = ipi04) or
                    (ipi.CST = ipi05) or (ipi.CST = ipi51) or
                    (ipi.CST = ipi52) or (ipi.CST = ipi53) or
                    (ipi.CST = ipi54) or (ipi.CST = ipi55)) then
                  begin
                    // não envia nada somente o cst conforme manual
                  end;

                  // se for entrada
                  if Ide.tpNF = tnEntrada then
                  begin
                    // 00=Entrada com recuperação de crédito
                    if (ipi.CST = ipi00) then
                    begin

                      // verifica se trabalha o calculo de imposto por percentual ou valor * por unidade / quantidade
                      // Informar os campos O10 e O13 se o cálculo do IPI for por alíquota.
                      if JsonIPI.Get('calc_ipi_aliqvalor', '') =
                        'A' then
                      begin
                        ipi.vBC := JsonIPI.Get('vBC', 0.0);
                        // Valor da BC do IPI
                        ipi.pIPI := JsonIPI.Get('pIPI', 0.0);
                        // Aliquota do IPI
                        ipi.vIPI := JsonIPI.Get('vIPI', 0.0);
                        // Valor do IPI

                      end
                      else
                      begin
                        // Quantidade total na unidade padrão para tributação (somente para os produtos tributados por unidade)
                        ipi.qUnid := JsonIPI.Get('qUnid', 0);
                        // Valor do IPI por unidade
                        ipi.vUnid := JsonIPI.Get('vUnid', 0);
                        // Valor do IPI
                        // Valor do IPI por unidade
                        ipi.vIPI := JsonIPI.Get('vIPI', 0.0);
                        // Valor do IPI

                      end;

                    end;
                  end;

                  // 49=Outras entradas
                  if (ipi.CST = ipi49) then
                  begin
                    // verifica se trabalha o calculo de imposto por percentual ou valor * por unidade / quantidade
                    // Informar os campos O10 e O13 se o cálculo do IPI for por alíquota.
                    if JsonIPI.Get('calc_ipi_aliqvalor', '') =
                      'A' then
                    begin
                      ipi.vBC := JsonIPI.Get('vBC', 0.0);
                      // Valor da BC do IPI
                      ipi.pIPI := JsonIPI.Get('pIPI', 0);
                      // Aliquota do IPI
                      ipi.vIPI := JsonIPI.Get('vIPI', 0.0);
                      // Valor do IPI
                    end
                    else
                      // se for um percentual sobre a quantidade / Informar os campos O11 e O12 se o cálculo do IPI for de valor
                    begin
                      // Quantidade total na unidade padrão para tributação (somente para os produtos tributados por unidade)
                      ipi.qUnid := JsonIPI.Get('qUnid', 0);
                      // Valor do IPI por unidade
                      ipi.vUnid := JsonIPI.Get('vUnid', 0);
                      ;
                      // Valor do IPI
                      // Valor do IPI por unidade
                      ipi.vIPI := JsonIPI.Get('vIPI', 0.0);
                      // Valor do IPI
                    end;

                  end;

                  // 50=Saída tributada
                  if (ipi.CST = ipi50) then
                  begin

                    // verifica se trabalha o calculo de imposto por percentual ou valor * por unidade / quantidade
                    // Informar os campos O10 e O13 se o cálculo do IPI for por alíquota.
                    if JsonIPI.Get('calc_ipi_aliqvalor', '') =
                      'A' then
                    begin
                      ipi.vBC := JsonIPI.Get('vBC', 0.0);
                      // Valor da BC do IPI
                      ipi.pIPI := JsonIPI.Get('pIPI', 0);
                      // Aliquota do IPI
                      ipi.vIPI := JsonIPI.Get('vIPI', 0.0);
                      // Valor do IPI
                    end
                    else
                      // se for um percentual sobre a quantidade / Informar os campos O11 e O12 se o cálculo do IPI for de valor
                    begin
                      // Quantidade total na unidade padrão para tributação (somente para os produtos tributados por unidade)
                      ipi.qUnid := JsonIPI.Get('qUnid', 0);
                      // Valor do IPI por unidade
                      ipi.vUnid := JsonIPI.Get('vUnid', 0);
                      // Valor do IPI
                      // Valor do IPI por unidade
                      ipi.vIPI := JsonIPI.Get('vIPI', 0.0);
                      // Valor do IPI
                    end;

                  end;

                  // 99=Outras saídas
                  if (ipi.CST = ipi99) then
                  begin

                    // verifica se trabalha o calculo de imposto por percentual ou valor * por unidade / quantidade
                    // Informar os campos O10 e O13 se o cálculo do IPI for por alíquota.
                    if JsonIPI.Get('calc_ipi_aliqvalor', '') =
                      'A' then
                    begin
                      ipi.vBC := JsonIPI.Get('vBC', 0.0);
                      // Valor da BC do IPI
                      ipi.pIPI := JsonIPI.Get('pIPI', 0);
                      // Aliquota do IPI
                      ipi.vIPI := JsonIPI.Get('vIPI', 0.0);
                      // Valor do IPI
                    end
                    else
                      // se for um percentual sobre a quantidade / Informar os campos O11 e O12 se o cálculo do IPI for de valor
                    begin
                      // Quantidade total na unidade padrão para tributação (somente para os produtos tributados por unidade)
                      ipi.qUnid := JsonIPI.Get('qUnid', 0);
                      // Valor do IPI por unidade
                      ipi.vUnid := JsonIPI.Get('vUnid', 0);
                      // Valor do IPI
                      // Valor do IPI por unidade
                      ipi.vIPI := JsonIPI.Get('vIPI', 0.0);
                      // Valor do IPI
                    end;

                  end;

                end
                else // se for um serviço -  Tipo_item := TpServico
                begin
                  JsonISS := JsonImposto.Objects['ISSQN'];  //Get('ISSQN') as TJSONObject;

                  if trim(JsonISS.Get('eventos', '')) = 'S' then
                    eventos := True
                  else
                    eventos := False;

                  ISSQN.vBC := JsonISS.Get('vBC', 0.0);
                  ISSQN.vAliq := JsonISS.Get('vAliq', 0);
                  ISSQN.vISSQN := JsonISS.Get('vISSQN',0.0);
                  ISSQN.cMunFG := JsonISS.Get('cMunFG', 0);

                  if Length(trim(JsonISS.Get('cListServ', ''))) = 4 then
                    ISSQN.cListServ :=
                      '0' + JsonISS.Get('cListServ', '')
                  else
                    ISSQN.cListServ :=
                      JsonISS.Get('cListServ', '');

                  ISSQN.cSitTrib := ISSQNcSitTribNORMAL;
                  ISSQN.vDeducao := 0;
                  ISSQN.vOutro := 0;

                  ISSQN.vDescIncond :=
                    JsonISS.Get('vDescIncond', 0);
                  ISSQN.vDescIncond :=
                    JsonISS.Get('vDescIncond', 0);

                  ISSQN.indISSRet := iirNao;
                  ISSQN.vISSRet := 0;
                  ISSQN.indISS := iiExigivel;
                  ISSQN.cServico := JsonISS.Get('cServico', '');
                  ISSQN.cMun := Emit.EnderEmit.cMun;
                  ISSQN.cPais := 1058;
                  ISSQN.nProcesso := '';
                  ISSQN.indIncentivo := iiNao;

                end;

                // -------------------------- começo do pis ---------------------------
                JsonPIS := JsonImposto.Objects['PIS']; //Get('PIS') as TJSONObject;

                pis.CST := Retorna_PIS(JsonPIS.Get('cst', ''));

                if (pis.CST = pis01) or (pis.CST = pis02) then
                  // if (formatfloat('00',adqryLstDetalheNFCSTPIS.AsInteger)='01') or (formatfloat('00',adqryLstDetalheNFCSTPIS.AsInteger)='02') then
                begin
                  pis.vBC := JsonPIS.Get('vBC', 0.0);
                  // Valor da Base de Cálculo do PIS
                  pis.pPIS := JsonPIS.Get('pPIS', 0);
                  // Alíquota em Percencual do PIS
                  pis.vPIS := JsonPIS.Get('vPIS', 0.0);
                  // Valor do PIS
                end;

                if (pis.CST = pis03) then
                  // if (formatfloat('00',adqryLstDetalheNFCSTPIS.AsInteger)='01') or (formatfloat('00',adqryLstDetalheNFCSTPIS.AsInteger)='02') then
                begin
                  pis.qBCprod := JsonPIS.Get('qBCProd', 0.0);
                  // Quantidade Vendida
                  pis.vAliqProd := JsonPIS.Get('vAliqProd', 0);
                  // Alíquota do PIS (em reais)
                  pis.vPIS := JsonPIS.Get('vPIS', 0.0);
                  // Valor do PIS
                end;

                if (pis.CST in [pis49, pis50, pis51, pis52, pis53,
                  pis54, pis55, pis56, pis60, pis61, pis63,
                  pis64, pis66, pis67, pis70, pis71, pis72, pis73,
                  pis74, pis75, pis98]) then
                begin
                  pis.vBC := JsonPIS.Get('vBC', 0.0);
                  // Valor da Base de Cálculo do PIS
                  pis.pPIS := JsonPIS.Get('pPIS', 0);
                  // Alíquota em Percencual do PIS
                  pis.vPIS := JsonPIS.Get('vPIS', 0.0);
                  // Valor do PIS
                end;

                if (pis.CST = pis99) then
                  // if (formatfloat('00',adqryLstDetalheNFCSTPIS.AsInteger)='01') or (formatfloat('00',adqryLstDetalheNFCSTPIS.AsInteger)='02') then
                begin
                  pis.vBC := JsonPIS.Get('vBC', 0.0);
                  // Valor da Base de Cálculo do PIS
                  pis.pPIS := JsonPIS.Get('pPIS', 0);
                  // Alíquota em Percencual do PIS
                  pis.vPIS := JsonPIS.Get('vPIS', 0.0);
                  // Valor do PIS
                end;

                { with PISST do
                  begin
                  vBc       := 0;
                  pPis      := 0;
                  qBCProd   := 0;
                  vAliqProd := 0;
                  vPIS      := 0;
                  end; }

                // ------------- começo do cofins -----------------------------------
                JsonCofins := JsonImposto.Objects['COFINS'];   //Get('COFINS') as TJSONObject;

                cofins.CST :=
                  Retorna_COFINS(JsonCofins.Get('cst', ''));
                // Código de Situacao Tributária - ver opções no Manual
                if (cofins.CST = cof01) or (cofins.CST = cof02) then
                begin
                  cofins.vBC := JsonCofins.Get('vBC', 0.0);
                  // Valor da Base de Cálculo do COFINS
                  cofins.pCOFINS := JsonCofins.Get('pCOFINS', 0);
                  // Alíquota do COFINS em Percentual
                  cofins.vCOFINS := JsonCofins.Get('vCOFINS', 0.0);
                  // Valor do COFINS em Reais
                end;

                if (cofins.CST = cof03) then
                begin
                  cofins.qBCprod := JsonCofins.Get('qBCProd', 0);
                  // Valor da Base de Cálculo do COFINS
                  cofins.vAliqProd :=
                    JsonCofins.Get('vAliqProd', 0);
                  // Alíquota do COFINS em Percentual
                  cofins.vCOFINS := JsonCofins.Get('vCOFINS', 0.0);
                  // Valor do COFINS em Reais
                end;

                if (cofins.CST in [cof49, cof50, cof51, cof52, cof53,
                  cof54, cof55, cof56, cof60, cof61, cof63,
                  cof64, cof66, cof67, cof70, cof71, cof72, cof73,
                  cof74, cof75, cof98]) then
                begin
                  cofins.vBC := JsonCofins.Get('vBC', 0.0);
                  // Valor da Base de Cálculo do COFINS
                  cofins.pCOFINS := JsonCofins.Get('pCOFINS', 0);
                  // Alíquota do COFINS em Percentual
                  cofins.vCOFINS := JsonCofins.Get('vCOFINS', 0.0);
                  // Valor do COFINS em Reais

                  { cofins.qBCProd := qryLstDetalheNFQUANTIDADE.AsFloat;
                    // Valor da Base de Cálculo do COFINS
                    cofins.vAliqProd := qryLstDetalheNFTAXA_COFINS.AsFloat;
                    // Alíquota do COFINS em Percentual }
                end;

                if (cofins.CST = cof99) then
                begin
                  cofins.vBC := JsonCofins.Get('vBC', 0.0);
                  // Valor da Base de Cálculo do COFINS
                  cofins.pCOFINS := JsonCofins.Get('pCOFINS', 0);
                  // Alíquota do COFINS em Percentual
                  cofins.vCOFINS := JsonCofins.Get('vCOFINS', 0.0);
                  // Valor do COFINS em Reais

                  // cofins.qBCProd := qryLstDetalheNFQUANTIDADE.AsFloat;
                  // Valor da Base de Cálculo do COFINS
                  // cofins.vAliqProd := qryLstDetalheNFTAXA_COFINS.AsFloat;
                  // Alíquota do COFINS em Percentual
                end;
              end;
            end;

          end; // fi, lopp de produtos

        end; // if tem itens

        // ---------- tag do responsavel técnico --------------------
        JsoninfRespTec := JsonRaiz.Objects['infRespTec'];  //Get('infRespTec') as TJSONObject;
        infRespTec.cnpj := JsoninfRespTec.Get('CNPJ', '');
        infRespTec.xContato := JsoninfRespTec.Get('xContato', '');
        infRespTec.email := JsoninfRespTec.Get('email', '');
        infRespTec.Fone := JsoninfRespTec.Get('fone', '');

        // ------------ totais da nota -------------------
        Jsontotal := JsonRaiz.Objects['total'];     //Get('total') as TJSONObject;

        JsonICMSTot := Jsontotal.Objects['ICMSTot'];     //Get('ICMSTot') as TJSONObject;
        JsonISSQNtot := Jsontotal.Objects['ISSQNtot'];     //Get('ISSQNtot') as TJSONObject;

        // --------- se tem valor total de serviço ----------------------
        if JsonISSQNtot.Get('vServ', 0) > 0 then
        begin
          Total.ISSQNtot.vBC := JsonISSQNtot.Get('vBC', 0.0);

          Total.ISSQNtot.vISS := JsonISSQNtot.Get('vISS', 0);
          Total.ISSQNtot.vPIS := JsonISSQNtot.Get('vPIS', 0.0);
          Total.ISSQNtot.vCOFINS := JsonISSQNtot.Get('vCOFINS', 0.0);
          Total.ISSQNtot.dCompet :=
            formatadata_json(JsonISSQNtot.Get('dCompet', ''));
          Total.ISSQNtot.vDeducao := 0;
          Total.ISSQNtot.vOutro := 0;
          // Desconto condicional

          Total.ISSQNtot.vDescIncond :=
            JsonISSQNtot.Get('vDescIncond', 0);
          Total.ISSQNtot.vDescCond :=
            JsonISSQNtot.Get('vDescCond', 0);
          Total.ISSQNtot.vServ := JsonISSQNtot.Get('vServ', 0.0);
          Total.ISSQNtot.vISSRet := 0;

          Total.ISSQNtot.cRegTrib :=
            Retorna_crt_empresa_Servico(JsonISSQNtot.Get('cRegTrib', 0));

        end;

        // ------------ Totais referentes a produtos -----------------------
        Total.ICMSTot.vBC := JsonICMSTot.Get('vBC', 0.0);
        // Base de Cálculo do ICMS
        Total.ICMSTot.vICMS := JsonICMSTot.Get('vICMS', 0.0);
        // Valor Total do ICMS
        Total.ICMSTot.vBCST := JsonICMSTot.Get('vBCST', 0.0);
        // Base de Cálculo do ICMS Subst. Tributária
        Total.ICMSTot.vST := JsonICMSTot.Get('vST', 0.0);
        // Valor Total do ICMS Sibst. Tributária
        Total.ICMSTot.vProd := JsonICMSTot.Get('vProd', 0.0);
        // +  adqryLstCabecalhoNFTOTALSERVICOS.AsCurrency;
        // Valor Total de Produtos
        // Total.ICMSTot.vFrete := cdsLstbasefrete.AsFloat;// Valor Total de Fretes
        Total.ICMSTot.vSeg := JsonICMSTot.Get('vSeg', 0.0);
        Total.ICMSTot.vDesc := JsonICMSTot.Get('vDesc', 0.0);
        // Valor Total de Desconto
        Total.ICMSTot.vII := 0; // Valor Total do II;
        Total.ICMSTot.vIPI := JsonICMSTot.Get('vIPI', 0.0);
        // Valor Total do IPI
        Total.ICMSTot.vPIS := JsonICMSTot.Get('vPIS', 0.0);
        // Valor Total do PIS
        Total.ICMSTot.vCOFINS := JsonICMSTot.Get('vCOFINS', 0.0);
        // Valor Total do COFINS

        Total.ICMSTot.vOutro := JsonICMSTot.Get('vOutro', 0.0);
        // Outras Despesas Acessórias
        Total.ICMSTot.vNF := JsonICMSTot.Get('vNF', 0.0);
        // Valor Total da NFe

        // Base de Cálculo do ICMS Subst. Tributária
        Total.ICMSTot.vICMSDeson :=
          JsonICMSTot.Get('vICMSDeson', 0);

        if Ide.finNFe in [fnDevolucao] then
          Total.ICMSTot.vIPIDevol := 0;

        // lei da transparencia de impostos
        if JsonICMSTot.Get('vTotTrib', 0.0) > 0 then
          Total.ICMSTot.vTotTrib := JsonICMSTot.Get('vTotTrib',0.0);

        { Total.ISSQNtot.vServ := 100;
          Total.ISSQNtot.vBC := 100;
          Total.ISSQNtot.vISS := 2;
          Total.ISSQNtot.vPIS := 0;
          Total.ISSQNtot.vCOFINS := 0; }

        { Total.retTrib.vRetPIS    := 0;
          Total.retTrib.vRetCOFINS := 0;
          Total.retTrib.vRetCSLL   := 0;
          Total.retTrib.vBCIRRF    := 0;
          Total.retTrib.vIRRF      := 0;
          Total.retTrib.vBCRetPrev := 0;
          Total.retTrib.vRetPrev   := 0; }

        if modelo = apmNFe then
        begin
          if booNfePartilha = True then
          begin

            // Partilha do ICMS apenas a partir do dia
            Total.ICMSTot.vFCPUFDest :=
              JsonICMSTot.Get('vFCPUFDest', 0.0);
            Total.ICMSTot.vICMSUFDest :=
              JsonICMSTot.Get('vICMSUFDest', 0.0);
            // Se a Empresa for Simples, a aliquota pro estado de Origem é 0
            if Emit.CRT <> crtRegimeNormal then
              Total.ICMSTot.vICMSUFRemet := 0
            else
              Total.ICMSTot.vICMSUFRemet :=
                JsonICMSTot.Get('vICMSUFRemet',0.0);
          end;

          // --- bloco de transp ----------------------

          Jsontransp := JsonRaiz.Objects['transp'];//Get('transp') as TJSONObject;

          // frete
          Transp.modFrete := Retorna_Tipo_Frete(
            Jsontransp.Get('modFrete', 0));

          Jsontransportadora := Jsontransp.Objects['transporta']; //Get('transporta') as TJSONObject;

          if Ide.idDest = doInterestadual then
          begin
            Transp.Transporta.CNPJCPF :=
              Jsontransportadora.Get('CNPJCPF', '');
            Transp.Transporta.xNome := Jsontransportadora.Get('xNome', '');
            Transp.Transporta.IE := Jsontransportadora.Get('IE', '');
            Transp.Transporta.xEnder :=
              Jsontransportadora.Get('xEnder', '');
            Transp.Transporta.xMun := Jsontransportadora.Get('xMun', '');
            Transp.Transporta.UF := Jsontransportadora.Get('UF', '');

          end
          else
          begin

            if Transp.modFrete in [mfContaEmitente, mfContaDestinatario] then
            begin
              Transp.Transporta.CNPJCPF :=
                Jsontransportadora.Get('CNPJCPF', '');
              Transp.Transporta.xNome :=
                Jsontransportadora.Get('xNome', '');
              Transp.Transporta.IE := Jsontransportadora.Get('IE', '');
              Transp.Transporta.xEnder :=
                Jsontransportadora.Get('xEnder', '');
              Transp.Transporta.xMun :=
                Jsontransportadora.Get('xMun', '');
              Transp.Transporta.UF := Jsontransportadora.Get('UF', '');
            end
            else
            begin
              Transp.Transporta.CNPJCPF := '';
              Transp.Transporta.xNome := '';
              Transp.Transporta.IE := '';
              Transp.Transporta.xEnder := '';
              Transp.Transporta.xMun := '';
              Transp.Transporta.UF := '';
            end;

          end;

          // volumes do transporte
          JsonVolumes := Jsontransp.Arrays['vol']; //Get('vol') as TJSONArray;
          if (JsonVolumes <> nil) and (JsonVolumes.Count > 0) then
          begin

            for item_vol := 0 to JsonVolumes.Count - 1 do
            begin
              with Transp.Vol.Add do
              begin
                //JsonVolumes_Dados := JsonVolumes.Items[i] as TJSONObject;

                qVol := JsonVolumes.Objects[item_vol].Get('qVol', 0);
                esp := JsonVolumes.Objects[item_vol].Get('esp', '');
                marca := JsonVolumes.Objects[item_vol].Get('marca', '');
                nVol := JsonVolumes.Objects[item_vol].Get('nVol', '');
                pesoL := JsonVolumes.Objects[item_vol].Get('pesoL', 0);
                pesoB := JsonVolumes.Objects[item_vol].Get('pesoB', 0);

              end;
            end;
          end;

          // veiculo de transporte
          JsonVeiTransp := Jsontransp.Objects['transporta']; //Get('transporta') as TJSONObject;

          Transp.veicTransp.placa := JsonVeiTransp.Get('placa', '');
          Transp.veicTransp.UF := JsonVeiTransp.Get('UF', '');
          Transp.veicTransp.RNTC := '';

          // --- bloco de cobr ----------------------

          // Dados da Fatura

          if Ide.indPag = ipPrazo then
            // (0- a Vista, 1 -  a Prazo, 2 - outros) then
          begin
            Jsoncob := JsonRaiz.Objects['cobr']; //Get('cobr') as TJSONObject;
            Cobr.Fat.nFat := Jsoncob.Get('nFat', '');
            Cobr.Fat.vOrig := Jsoncob.Get('vOrig', 0.0);
            ;
            Cobr.Fat.vDesc := Jsoncob.Get('vDesc', 0.0);
            Cobr.Fat.vLiq := Jsoncob.Get('vLiq', 0.0);

            // duplicatas da cobrança
            Jsondup := Jsoncob.Arrays['dup']; //Get('dup') as TJSONArray;
            if (Jsondup <> nil) and (Jsondup.Count > 0) then
            begin

              Jsondup := Jsoncob.Arrays['cobr']; //Get('cobr') as TJSONArray;
              for item_dup := 0 to Jsondup.Count - 1 do
              begin
                with Cobr.Dup.Add do
                begin
                  Jsondup_Dados := Jsondup.Items[i] as TJSONObject;

                  // PA estava rejeitando nota a prazo com entrada, fica duas parcelas com cod 001
                  if ((Emit.EnderEmit.UF = 'PA') or
                    (Emit.EnderEmit.UF = 'MA') or (Emit.EnderEmit.UF = 'RJ')) then
                    nDup := formatfloat('000', i)
                  else
                    nDup := formatfloat('000',
                      Jsondup_Dados.Get('nDup', 0));

                  dVenc := formatadata_json(
                    Jsondup_Dados.Get('dVenc', ''));
                  // Data de Vencimento
                  vDup := Jsondup_Dados.Get('vDup', 0.0);
                  // Valor do Pagamento;

                end;
              end;
            end;

          end
          else // se for pagamento aprazo
          begin
            if Emit.EnderEmit.UF = 'AM' then
            begin
              // Mostra uma parcela como avista
              if Ide.indPag = ipVista then
              begin
                Jsoncob := JsonRaiz.Objects['cobr'];  //Get('cobr') as TJSONObject;

                Cobr.Fat.nFat := Jsoncob.Get('nFat', '');
                Cobr.Fat.vOrig := Jsoncob.Get('vOrig', 0.0);
                ;
                Cobr.Fat.vDesc := Jsoncob.Get('vDesc', 0.0);
                Cobr.Fat.vLiq := Jsoncob.Get('vLiq', 0.0);

                // Parcelas = Duplicatas
                Jsondup := Jsoncob.Arrays['cobr']; //Get('cobr') as TJSONArray;
                for item_dup := 0 to Jsondup.Count - 1 do
                begin
                  Jsondup_Dados := Jsondup.Items[i] as TJSONObject;
                  with Cobr.Dup.Add do
                  begin

                    nDup := 'AVISTA';
                    dVenc := date;
                    // Data de Vencimento
                    vDup := Jsontotal.Get('vServ', 0.0);
                    ;
                    // Valor do Pagamento;

                  end;
                end;

              end;

            end;
          end;

        end // fim se for nfe
        else // se for nfce
        begin
          Transp.modFrete := mfSemFrete;
        end;

        // -------- Forma de Pagamento ----------------------

        if modelo = apmNFe then
        begin

          { Quando emitido uma NF-e com finalidade ajuste ou Devolução (finNFe = 3 ou 4),
            e a forma de pagamento (tPag) for diferente de 90, será retornado
            a rejeição 871: "O campo forma de pagamento deve ser preenchido
            com a opção sem pagamento". }
          if (Ide.finNFe in [fnDevolucao, fnAjuste]) then
          begin
            ACBrNFe.NotasFiscais.Add.nfe.pag.Add.tPag := fpSemPagamento;
          end
          else
          begin
            // se for avista ou nenhum tipo
            if Ide.indPag in [ipVista, ipNenhum] then
              // (0- a Vista, 1 -  a Prazo, 2 - outros) then
            begin
              with pag.Add do
              begin
                ACBrNFe.NotasFiscais.Add.nfe.pag.Add.tPag := fpSemPagamento;
              end;
            end
            else // se for aprazo  qryLstBaseID_TIPO_PAGTO.AsInteger=2
            begin

              // pega o conteudo do json array dentro do objeto ide
              jsonPag := JsonRaiz.Arrays['pag']; //Get('pag') as TJSONArray;
              if (jsonPag <> nil) and (jsonPag.Count > 0) then
              begin
                for item_pag := 0 to jsonPag.Count - 1 do
                begin
                  with pag.Add do
                  begin
                    jsonPag_Dados := jsonPag.Items[item_pag] as TJSONObject;

                    tPag := Retorna_FormaPagamento(
                      jsonPag_Dados.Get('tPag', 0));

                    // Forma de pagamento
                    vPag := jsonPag_Dados.Get('vPag', 0.0);

                    if Retorna_FormaPagamento(
                      jsonPag_Dados.Get('tPag', 0)) = fpOutro then
                      xPag := jsonPag_Dados.Get('xPag', '');

                    // se o grupo for cartão de crédito / debito
                    if jsonPag_Dados.Get('tPag', 0) in [3, 4] then
                    begin
                      tpIntegra := tiPagNaoIntegrado;
                      // = Pagamento não integrado com o sistema de automação da empresa (Ex.: equipamento POS);
                    end;

                  end;
                end;
              end
              else
                pag.new.tPag := fpSemPagamento;

            end;
          end;

        end
        else // se for nfce
        begin
          // Parcelas = Duplicatas
          // pega o conteudo do json array dentro do objeto ide
          jsonPag := JsonRaiz.Arrays['pag']; //Get('pag') as TJSONArray;
          if (jsonPag <> nil) and (jsonPag.Count > 0) then
          begin
            for item_pag := 0 to jsonPag.Count - 1 do
            begin
              with pag.Add do
              begin
                jsonPag_Dados := jsonPag.Items[item_pag] as TJSONObject;

                tPag := Retorna_FormaPagamento(
                  jsonPag_Dados.Get('tPag', 0));

                if jsonPag_Dados.Get('tPag', 0) = 99 then
                begin
                  xPag := 'Outros';
                end;

                // Forma de pagamento
                vPag := jsonPag_Dados.Get('vPag', 0.0);
                // Valor do Pagamento

                // se o grupo for cartão de crédito / debito
                if jsonPag_Dados.Get('tPag', 0) in [3, 4] then
                begin

                  // Se modalidade for TEF, e gerou autorização
                  if (jsonPag_Dados.Get('tpIntegra', 0) > 0) then
                  begin
                    tpIntegra := tiPagIntegrado; // Pagamento integrado TEF
                    cAut := jsonPag_Dados.Get('cAut', '');
                    // Numero de Autorização do pagamento
                  end
                  else
                    tpIntegra := tiPagNaoIntegrado;
                  // = Pagamento não integrado com o sistema de automação da empresa (Ex.: equipamento POS);

                end;

              end;
            end;
          end;

        end; // fim se for nfce

        InfAdic.infCpl := JsonRaiz.Get('infCplt', '');
        InfAdic.infAdFisco := JsonRaiz.Get('infAdFisco', '');

        // exportação
        if tipo_pessoa = 'E' then
          // Se for entrada e uma importação de produtos
          if Ide.tpNF = tnSaida then
          begin
            Jsonexporta := JsonRaiz.Objects['exporta']; //Get('exporta') as TJSONObject;

            exporta.UFSaidaPais := Jsonexporta.Get('UFSaidaPais', '');
            exporta.xLocExporta := Jsonexporta.Get('xLocExporta', '');
            exporta.xLocDespacho := Jsonexporta.Get('xLocDespacho', '');
          end;

        json_retorno := TJSONObject.Create;
        json_retorno.Add('Status', 100);
        json_retorno.Add('xMotivo', 'xml gerado com sucesso');
        if eventos = True then
          json_retorno.Add('descricao_evento', descricao_evento)
        else
          json_retorno.Add('descricao_evento', descricao_evento);

        Result := json_retorno;
      end;

    except
      on ex: Exception do
      begin
        json_retorno := TJSONObject.Create;
        json_retorno.Add('Status', 500);
        json_retorno.Add('xMotivo', ex.Message);
        Result := json_retorno;
      end;
    end;

  finally

  end;

end;

procedure TdmPrincipal.gera_xml_adicoes_item(JsonDI: TJSONArray);
begin
  //
end;

function TdmPrincipal.Consulta_chave_acesso(cnpj, chave_acesso: string;
  modelo: TApiModeloDF): TJSONObject;
var
  retorno: Boolean;
  LJSONObject, retorno_autorizacao: TJSONObject;
  statussefaz, status_autorizacao, id_cliente_local: integer;
  chavenfe, xmotivo_xml, protocolo, digVal: string;
  dhRecbto: Tdatetime;
  qryConsultaNota: TZQuery;
begin
  if (cnpj = '') then
  begin
    LJSONObject := TJSONObject.Create;
    LJSONObject.Add('Status', '500');
    LJSONObject.Add('xMotivo', 'Informe uma chave de acesso');

    result := LJSONObject;
    exit;
  end;

  if (chave_acesso = '') then
  begin
    LJSONObject := TJSONObject.Create;
    LJSONObject.Add('Status', '500');
    LJSONObject.Add('xMotivo', 'Informe a chave de acesso');

    result := LJSONObject;
    exit;
  end;

  try

    if not conecta_banco then
    begin
      LJSONObject := TJSONObject.Create;
      LJSONObject.Add('Status', '500');
      LJSONObject.Add('xMotivo', 'Falha de conexão com o banco de dados');

      result := LJSONObject;
      exit;
    end;

    retorno := Retorna_Configuracao_NFe(cnpj, modelo);
    if retorno = true then
    begin
      try
        qryConsultaNota := TZQuery.Create(nil);
        qryConsultaNota.Connection := Conn;
        qryConsultaNota.sql.Clear;
        qryConsultaNota.sql.Add
          ('select n.id from notas n inner join empresa e on e.id=n.id_empresa '
          + ' where n.chave =:chave and e.cpf_cnpj =:cpf_cnpj');
        qryConsultaNota.Params[0].AsString := chave_acesso;
        qryConsultaNota.Params[1].AsString := cnpj;
        qryConsultaNota.open;

        if qryConsultaNota.IsEmpty then
        begin
          LJSONObject := TJSONObject.Create;
          LJSONObject.Add('Status', '500');
          LJSONObject.Add('xMotivo',
            'Chave de acesso não encontrada na base de dados!');

          result := LJSONObject;
          exit;
        end;

        id_cliente_local := qryConsultaNota.FieldByName('id').AsInteger;

        ACBrNFe.NotasFiscais.Clear;
        ACBrNFe.WebServices.Consulta.NFeChave := chave_acesso;
        ACBrNFe.WebServices.Consulta.Executar;

        statussefaz := ACBrNFe.WebServices.Consulta.cStat;
        if RetornoStatusEnvio(statussefaz) then
        begin
          chavenfe := ACBrNFe.WebServices.Consulta.protNFe.chNFe;

          xmotivo_xml := ACBrNFe.WebServices.Consulta.xMotivo;
          protocolo := ACBrNFe.WebServices.Consulta.protocolo;
          dhRecbto := ACBrNFe.WebServices.Consulta.protNFe.dhRecbto;
          digVal := ACBrNFe.WebServices.Consulta.protNFe.digVal;

          // confirma a autorizaação no banco de dados
          retorno_autorizacao := Confirma_autorizacao(id_cliente_local,
            dhRecbto, digVal, protocolo);
          status_autorizacao := retorno_autorizacao.Get('Status');  //GetValue<integer>('Status', 0);

          if status_autorizacao = 100 then
          begin
            retorno := true;
          end
          else
          begin
            xmotivo_xml := retorno_autorizacao.Get('xMotivo'); //GetValue<string>('xMotivo', '');

            // se a nota não existe na base de dados
            if status_autorizacao = 998 then  // erro interno da api
            begin
              // retorna que deu um erro não esperado
              statussefaz := 500;
              retorno := true;
            end
            else
            begin
              retorno := false;
              if ACBrNFe.WebServices.Consulta.xMotivo <> '' then
                xmotivo_xml := ACBrNFe.WebServices.Consulta.xMotivo;
            end;

          end;

        end
        else // se o retorno não foi autorizado
        begin
          retorno := false;
          xmotivo_xml := ACBrNFe.WebServices.Consulta.xMotivo;
        end;

        if retorno = true then
        begin
          LJSONObject := TJSONObject.Create;
          LJSONObject.Add('Status', 100);
          LJSONObject.Add('cStat', statussefaz);
          LJSONObject.Add('digVal', digVal);
          LJSONObject.Add('chNFe', chavenfe);
          LJSONObject.Add('Protocolo', protocolo);
          LJSONObject.Add('xMotivo', xmotivo_xml);
          LJSONObject.Add('dhRecbto', FormatDateTime('dd-mm-yyyy', dhRecbto));
          result := LJSONObject;
        end;

        if retorno = false then
        begin
          LJSONObject := TJSONObject.Create;
          LJSONObject.Add('Status', 100);
          LJSONObject.Add('cStat', statussefaz);
          LJSONObject.Add('xMotivo', xmotivo_xml);
          result := LJSONObject;
        end;

      except

        on ex: Exception do
        begin
          LJSONObject := TJSONObject.Create;
          LJSONObject.Add('Status', 500);
          LJSONObject.Add('xMotivo', ex.Message);

          result := LJSONObject;
        end;

      end;
    end;

  finally
    Libera_query_memoria(qryConsultaNota);
  end;

end;

function TdmPrincipal.cancelamento_chaveacesso(chave, cnpj, motivo: string;
  modelo: TApiModeloDF): TJSONObject;
var
  retorno: Boolean;
  LJSONObject, retorno_autorizacao: TJSONObject;
  statussefaz, status_autorizacao, id_venda_cliente, id_venda_local : integer;
  chavenfe, xmotivo_xml, protocolo: string;
  dhRecbto: Tdatetime;
  qryCadNota: TZQuery;
begin
  if (chave = '') then
  begin
    LJSONObject := TJSONObject.Create;
    LJSONObject.Add('Status', 500);
    LJSONObject.Add('xMotivo', 'Informe uma chave de acesso válida');

    result := LJSONObject;
    exit;
  end;

  if (cnpj = '') then
  begin
    LJSONObject := TJSONObject.Create;
    LJSONObject.Add('Status', 500);
    LJSONObject.Add('xMotivo', 'Informe um cnj válido!');

    result := LJSONObject;
    exit;
  end;

  if (motivo = '') then
  begin
    LJSONObject := TJSONObject.Create;
    LJSONObject.Add('Status', 500);
    LJSONObject.Add('xMotivo', 'Informe o motivo do cancelamento, minumi 15 caracteres!');

    result := LJSONObject;
    exit;
  end;

  try

    if not conecta_banco then
    begin
      LJSONObject := TJSONObject.Create;
      LJSONObject.Add('Status', 500);
      LJSONObject.Add('xMotivo', 'Falha de conexão com o banco de dados');

      result := LJSONObject;
      exit;
    end;

    qryCadNota := TZQuery.Create(nil);
    qryCadNota.Connection := Conn;
    qryCadNota.sql.Clear;
    qryCadNota.sql.Add('select n.id, n.id_cliente, n.digestvalue , n.cpf_identificado, ' +
      ' n.tipo_emissao_id, n.chave, n.data_emissao, n.total_nf, n.valor_icms, n.numero_protocolo, '
      + ' n.eventos, e.cpf_cnpj, e.uf as uf_estado, e.id_ambiente, e.logo,  n.data_autorizacao, n.id_empresa  '
      + ' from notas n, empresa e where e.cpf_cnpj=:cpf_cnpj and n.chave=:chave ' + ' and e.id=n.id_empresa');
    qryCadNota.ParamByName('cpf_cnpj').AsString := cnpj;
    qryCadNota.ParamByName('chave').AsString := chave;
    qryCadNota.open;

    if qryCadNota.IsEmpty then
    begin
      LJSONObject := TJSONObject.Create;
      LJSONObject.Add('Status', 500);
      LJSONObject.Add('xMotivo', 'NF solicitada não existe no servidor!');
      result := LJSONObject;
      exit;
    end;

    id_venda_cliente := qryCadNota.FieldByName('id_cliente').AsInteger;
    id_venda_local  :=  qryCadNota.FieldByName('id').AsInteger;

    chavenfe := qryCadNota.FieldByName('chave').AsString;
    cnpj := qryCadNota.FieldByName('cpf_cnpj').AsString;
    protocolo := qryCadNota.FieldByName('numero_protocolo').AsString;

    retorno := Retorna_Configuracao_NFe(cnpj, modelo);
    if retorno = false then
    begin
      LJSONObject := TJSONObject.Create;
      LJSONObject.Add('Status', 00);
      LJSONObject.Add('xMotivo', 'Erro ao carregar as configurações');
      result := LJSONObject;
      exit;
    end;

    ACBrNFe.EventoNFe.Evento.Clear;
    ACBrNFe.EventoNFe.idLote := id_venda_cliente;

    with ACBrNFe.EventoNFe.Evento.Add do
    begin
      infEvento.chNFe := chavenfe;
      infEvento.cnpj := cnpj;
      infEvento.dhEvento := Kernel_RetornaDataFuso(now,
        qryCadNota.FieldByName('uf_estado').AsString);
      infEvento.tpEvento := teCancelamento;
      infEvento.detEvento.xJust := motivo;
      // Protocolo de autorização
      infEvento.detEvento.nProt := protocolo;
    end;

    ACBrNFe.NotasFiscais.Assinar;
    ACBrNFe.EnviarEvento(id_venda_cliente);

    statussefaz := ACBrNFe.WebServices.EnvEvento.EventoRetorno.retEvento.Items[0].RetInfEvento.cStat;
    //ACBrNFe.WebServices.EnvEvento.EventoRetorno.cStat;
    xmotivo_xml :=  ACBrNFe.WebServices.EnvEvento.EventoRetorno.retEvento.Items[0].RetInfEvento.xMotivo;

    if RetornoStatusEnvio(statussefaz) then
    begin
      chavenfe := ACBrNFe.WebServices.EnvEvento.EventoRetorno.retEvento.Items[0]
        .RetInfEvento.chNFe;

      protocolo := ACBrNFe.WebServices.EnvEvento.EventoRetorno.retEvento.Items
        [0].RetInfEvento.nProt;
      dhRecbto := ACBrNFe.WebServices.EnvEvento.EventoRetorno.retEvento.Items[0]
        .RetInfEvento.dhRegEvento;

      qryCadNota.close;
      qryCadNota.sql.Clear;
      qryCadNota.sql.Add('select * from notas where id=:id');
      qryCadNota.ParamByName('id').AsInteger := id_venda_local;
      qryCadNota.open;

      qryCadNota.edit;
      qryCadNota.FieldByName('id_status').AsInteger := 3;//CANCELADA
      qryCadNota.FieldByName('protocolo_cancelamento').AsString := protocolo;
      qryCadNota.FieldByName('motivo_cancelamento').AsString := motivo;
      qryCadNota.FieldByName('data_cancelamento').AsDateTime := dhRecbto;

      qryCadNota.Post;

      retorno := true;
    end
    else
    begin
      // Rejeicao: Duplicidade de Evento
      if statussefaz = 573 then
      begin
        dhRecbto := ACBrNFe.WebServices.EnvEvento.EventoRetorno.retEvento.Items[0]
        .RetInfEvento.dhRegEvento;

        qryCadNota.close;
        qryCadNota.sql.Clear;
        qryCadNota.sql.Add('select * from notas where id=:id');
        qryCadNota.ParamByName('id').AsInteger := id_venda_local;
        qryCadNota.open;

        qryCadNota.edit;
        qryCadNota.FieldByName('id_status').AsInteger := 3; //CANCELADA
        qryCadNota.FieldByName('motivo_cancelamento').AsString := motivo;
        //qryCadNota.FieldByName('protocolo_cancelamento').AsString := protocolo;
        qryCadNota.FieldByName('data_cancelamento').AsDateTime := dhRecbto;

        qryCadNota.Post;

        retorno := true;
      end
      else
       retorno := false;

    end;

    if retorno = true then
    begin
      LJSONObject := TJSONObject.Create;
      LJSONObject.Add('chNFe', chavenfe);
      LJSONObject.Add('nProt', protocolo);
      LJSONObject.Add('Status', 100);
      LJSONObject.Add('cStat', statussefaz);
      LJSONObject.Add('xMotivo', xmotivo_xml);
      result := LJSONObject;
    end;

    if retorno = false then
    begin
      LJSONObject := TJSONObject.Create;
      LJSONObject.Add('Status', 100);
      LJSONObject.Add('cStat', statussefaz);
      LJSONObject.Add('xMotivo', xmotivo_xml);
      result := LJSONObject;
    end;

  finally
    qryCadNota.Free;
  end;

end;

function TdmPrincipal.Cancelamento_id(id_cliente_local: integer;
  motivo: string; modelo: TApiModeloDF): TJSONObject;
var
  retorno: Boolean;
  LJSONObject, retorno_autorizacao: TJSONObject;
  statussefaz, status_autorizacao, id_venda_cliente: integer;
  chavenfe, xmotivo_xml, protocolo, cnpj: string;
  dhRecbto: Tdatetime;
  qryCadNota: TZQuery;
begin

  if (id_cliente_local <=0) then
  begin
    LJSONObject := TJSONObject.Create;
    LJSONObject.Add('Status', 500);
    LJSONObject.Add('xMotivo', 'Informe o id da nota autorizada na api');

    result := LJSONObject;
    exit;
  end;

  if (motivo = '') then
  begin
    LJSONObject := TJSONObject.Create;
    LJSONObject.Add('Status', 500);
    LJSONObject.Add('xMotivo', 'Informe o motivo do cancelamento, minumi 15 caracteres!');

    result := LJSONObject;
    exit;
  end;

  try

    if not conecta_banco then
    begin
      LJSONObject := TJSONObject.Create;
      LJSONObject.Add('Status', 500);
      LJSONObject.Add('xMotivo', 'Falha de conexão com o banco de dados');

      result := LJSONObject;
      exit;
    end;

    qryCadNota := TZQuery.Create(nil);
    qryCadNota.Connection := Conn;
    qryCadNota.sql.Clear;
    qryCadNota.sql.Add('select n.id, n.id_cliente, n.digestvalue , n.cpf_identificado, ' +
      ' n.tipo_emissao_id, n.chave, n.data_emissao, n.total_nf, n.valor_icms, n.numero_protocolo, '
      + ' n.eventos, e.cpf_cnpj, e.uf as uf_estado, e.id_ambiente, e.logo,  n.data_autorizacao, n.id_empresa  '
      + ' from notas n, empresa e where n.id=:id ' + ' and e.id=n.id_empresa');
    qryCadNota.Params[0].AsInteger := id_cliente_local;
    qryCadNota.open;

    if qryCadNota.IsEmpty then
    begin
      LJSONObject := TJSONObject.Create;
      LJSONObject.Add('Status', 500);
      LJSONObject.Add('xMotivo', 'NF solicitada não existe no servidor!');
      result := LJSONObject;
      exit;
    end;

    id_venda_cliente := qryCadNota.FieldByName('id_cliente').AsInteger;
    chavenfe := qryCadNota.FieldByName('chave').AsString;
    cnpj := qryCadNota.FieldByName('cpf_cnpj').AsString;
    protocolo := qryCadNota.FieldByName('numero_protocolo').AsString;

    retorno := Retorna_Configuracao_NFe(cnpj, modelo);
    if retorno = false then
    begin
      LJSONObject := TJSONObject.Create;
      LJSONObject.Add('Status', 500);
      LJSONObject.Add('xMotivo', 'Erro ao carregar as configurações');
      result := LJSONObject;
      exit;
    end;

    ACBrNFe.EventoNFe.Evento.Clear;
    ACBrNFe.EventoNFe.idLote := id_venda_cliente;

    with ACBrNFe.EventoNFe.Evento.Add do
    begin
      infEvento.chNFe := chavenfe;
      infEvento.cnpj := cnpj;
      infEvento.dhEvento := Kernel_RetornaDataFuso(now,
        qryCadNota.FieldByName('uf_estado').AsString);
      infEvento.tpEvento := teCancelamento;
      infEvento.detEvento.xJust := motivo;
      // Protocolo de autorização
      infEvento.detEvento.nProt := protocolo;
    end;

    ACBrNFe.NotasFiscais.Assinar;
    ACBrNFe.EnviarEvento(id_venda_cliente);

    statussefaz := ACBrNFe.WebServices.EnvEvento.EventoRetorno.retEvento.Items[0].RetInfEvento.cStat;
    //ACBrNFe.WebServices.EnvEvento.EventoRetorno.cStat;
    xmotivo_xml :=  ACBrNFe.WebServices.EnvEvento.EventoRetorno.retEvento.Items[0].RetInfEvento.xMotivo;

    if RetornoStatusEnvio(statussefaz) then
    begin
      chavenfe := ACBrNFe.WebServices.EnvEvento.EventoRetorno.retEvento.Items[0]
        .RetInfEvento.chNFe;

      protocolo := ACBrNFe.WebServices.EnvEvento.EventoRetorno.retEvento.Items
        [0].RetInfEvento.nProt;
      dhRecbto := ACBrNFe.WebServices.EnvEvento.EventoRetorno.retEvento.Items[0]
        .RetInfEvento.dhRegEvento;

      qryCadNota.edit;
      qryCadNota.FieldByName('protocolo_cancelamento').AsString := protocolo;
      qryCadNota.FieldByName('motivo_cancelamento').AsString := motivo;
      qryCadNota.FieldByName('data_cancelamento').AsDateTime := dhRecbto;

      qryCadNota.Post;

      retorno := true;
    end
    else
    begin
      retorno := false;
    end;

    if retorno = true then
    begin
      LJSONObject := TJSONObject.Create;
      LJSONObject.Add('chNFe', chavenfe);
      LJSONObject.Add('Protocolo', protocolo);
      LJSONObject.Add('Status', 100);
      LJSONObject.Add('cStat', statussefaz);
      LJSONObject.Add('xMotivo', xmotivo_xml);
      result := LJSONObject;
    end;

    if retorno = false then
    begin
      LJSONObject := TJSONObject.Create;
      LJSONObject.Add('Status', 100);
      LJSONObject.Add('cStat', statussefaz);
      LJSONObject.Add('xMotivo', xmotivo_xml);
      result := LJSONObject;
    end;

  finally
    qryCadNota.Free;
  end;
end;

function TdmPrincipal.onExporta_XML(JsonRaiz: TJSONObject; modelo: TApiModeloDF
  ): TJSONObject;
var
  retorno: Boolean;
  LJSONObject: TJSONObject;
  jsonChaves : TJSONArray;
  qryconfig, qryLstEmpresa: TZQuery;
  pasta_mesano ,arquivoDestino, pasta_zip, arquivo_zip_dominio,
  diretorio_app, diretorio_dominio, sBase64_pdf, cnpj,
  chave_acesso, strXML, strXMLNovo : string;
  id_empresa, mes, ano, item_chaves  : integer;
begin
  //  to do - ver se precisar de algum limite de download por dia

  mes := JsonRaiz.Get('mes', 0);
  ano := JsonRaiz.Get('ano', 0);
  cnpj := JsonRaiz.Get('cnpj', '');

  if (ano <= 0 ) then
  begin
  LJSONObject := TJSONObject.Create;
  LJSONObject.Add('Status', 500);
  LJSONObject.Add('xMotivo', 'Informe um numéro inicial');
  result := LJSONObject;
  exit;
  end;

  if (mes <= 0) then
  begin
  LJSONObject := TJSONObject.Create;
  LJSONObject.Add('Status', 500);
  LJSONObject.Add('xMotivo', 'Informe um numéro final');
  result := LJSONObject;
  exit;
  end;

  if ( cnpj = '' ) then
  begin
   LJSONObject := TJSONObject.Create;
   LJSONObject.Add('Status', 500);
   LJSONObject.Add('xMotivo', 'Informe um numéro final');
   result := LJSONObject;
   exit;
  end;

  try

   try

     if not conecta_banco then
     begin
       LJSONObject := TJSONObject.Create;
       LJSONObject.Add('Status', 500);
       LJSONObject.Add('xMotivo', 'Falha de conexão com o banco de dados');

       result := LJSONObject;
       exit;
     end;

     qryLstEmpresa := TZQuery.Create(nil);
     qryLstEmpresa.Connection := Conn;

     qryconfig := TZQuery.Create(nil);
     qryconfig.Connection := Conn;

     qryLstEmpresa.close;
     qryLstEmpresa.sql.Clear;
     qryLstEmpresa.sql.Add('select * from empresa where cpf_cnpj=:cnpj'+
       ' and local_instalacao=1');
     qryLstEmpresa.Params[0].AsString := cnpj;
     qryLstEmpresa.open;

     qryconfig.close;
     qryconfig.sql.Clear;
     qryconfig.sql.Add('select * from config');
     qryconfig.open;

     id_empresa := qryLstEmpresa.FieldByName('id').AsInteger;
     caminho_respostas := qryconfig.FieldByName('diretorio_respostas').AsString;
     diretorio_app := qryconfig.FieldByName('diretorio_app').AsString;
     diretorio_dominio := qryconfig.FieldByName('diretorio_dominio').AsString;

     qryconfig.close;
     qryconfig.sql.Clear;
     qryconfig.sql.Add('select * from notas where ano=:ano and mes=:mes and id_empresa =:id_empresa');
     qryconfig.ParamByName('ano').AsInteger := ano;
     qryconfig.ParamByName('mes').AsInteger := mes;
     qryconfig.ParamByName('id_empresa').Asinteger :=  id_empresa;
     qryconfig.open;

     if qryconfig.IsEmpty then
     begin
       LJSONObject := TJSONObject.Create;
       LJSONObject.Add('Status', 500);
       LJSONObject.Add('xMotivo', 'Nenhuma nota encontrada nesse mes, ano');

       result := LJSONObject;
       exit;
     end;

     pasta_zip := Retorna_pasta_diretorio_zip(caminho_respostas, id_empresa,
       ano, mes, apmNFCe, taZIP);
     //
     arquivoDestino := pasta_zip + 'backup.zip';

     // obter o caminho completo da pasta xml do ano e mes solicitado
     pasta_mesano :=  Retorna_pasta_diretorio_zip(caminho_respostas, id_empresa,
       ano, mes, apmNFCe, taxml) + Retorna_nome_pasta_xml_gerado(tp_xml_autorizado) + '\';

     // apaga o conteudo da pasta, para apagar lixo anterior
     if DirectoryExists(Kernel_DiretorioBarras(pasta_zip)) then
       Remove(pasta_zip);

     // faz a compactação da pasta
     jsonChaves := JsonRaiz.Arrays['chaves']; //GetValue('chaves') as TJSONArray;
     if (jsonChaves <> nil) and (jsonChaves.Count > 0) then
     begin
       for item_chaves := 0 to jsonChaves.Count - 1 do
       begin
         chave_acesso := jsonChaves.Objects[item_chaves].Get('chNFe'); //GetValue<string>('chNFe');

         // Tenta copiar o xml autorizado da nota para a pasta selecionada
         strXML     := Kernel_DiretorioBarras(pasta_mesano) + chave_acesso + '-nfe.xml';
         strXMLNOVO := Kernel_DiretorioBarras(pasta_zip) + chave_acesso + '-nfe.xml';

         // Se existir o xml na pasta respostas
         if FileExists(strXML) then
         begin
           if DirectoryExists(Kernel_DiretorioBarras(pasta_zip)) then
           begin
             if not Copy_File(strXML, strXMLNOVO) then
             begin
               LJSONObject := TJSONObject.Create;
               LJSONObject.Add('Status', 500);
               LJSONObject.Add('xMotivo', 'Falha na copia dos arquivos');

               result := LJSONObject;
               exit;
             end;
           end;
         end;

       end;
     end;

     // compactar todos os xmls da pasta, passa nome do arquivo e pasta de destino
     ZipDirectoryContents(arquivoDestino, pasta_zip);

     // gera base64 do arquivo zip
     sBase64_pdf := FileToBase64(arquivoDestino);

     // retorna o caminho do arquivo compactado
     LJSONObject := TJSONObject.Create;
     LJSONObject.Add('Status', 100);
     LJSONObject.Add('link_zip', sBase64_pdf);
     LJSONObject.Add('xMotivo', 'Arquivo gerado com sucesso');
     result := LJSONObject;

   except

     on ex: Exception do
     begin
       LJSONObject := TJSONObject.Create;
       LJSONObject.Add('Status', 500);
       LJSONObject.Add('xMotivo', ex.Message);

       result := LJSONObject;
     end;

   end;

  finally
    qryLstEmpresa.Free;
    qryconfig.Free;
  end;

end;

function TdmPrincipal.atualiza_fiscal(JsonRaiz: TJSONObject): TJSONObject;
var
  retorno: Boolean;
  LJSONObject: TJSONObject;
  qryCadEmpresa, qryLstempresa_env, qrycons: TZQuery;
  id_empresa: integer;
  local_instalacao: integer;
  cnpj, local_config, caminho_dir: string;

  caminho_cert, base64Data, pfxFilePath: string;
begin

  try

    if not conecta_banco then
    begin
      LJSONObject := TJSONObject.Create;
      LJSONObject.Add('Status', 500);
      LJSONObject.Add('xMotivo', 'Falha de conexão com o banco de dados');

      result := LJSONObject;
      exit;
    end;

    cnpj := JsonRaiz.Get('cnpj', '');
    local_instalacao := JsonRaiz.Get('local_instalacao'); //  GetValue<integer>('local_instalacao', 1);

    qryLstempresa_env := TZQuery.Create(nil);
    qryLstempresa_env.Connection := Conn;

    qrycons := TZQuery.Create(nil);
    qrycons.Connection := Conn;

    qryCadEmpresa := TZQuery.Create(nil);
    qryCadEmpresa.Connection := Conn;

    qryLstempresa_env.close;
    qryLstempresa_env.sql.Clear;
    qryLstempresa_env.sql.Add('select * from empresa where cpf_cnpj=:cpf_cnpj '
      + ' and local_instalacao=:local_instalacao');
    qryLstempresa_env.ParamByName('cpf_cnpj').AsString := cnpj;
    qryLstempresa_env.ParamByName('local_instalacao').AsInteger :=
      local_instalacao;
    qryLstempresa_env.open;

    if qryLstempresa_env.IsEmpty then
    begin
      LJSONObject := TJSONObject.Create;
      LJSONObject.Add('Status', 500);
      LJSONObject.Add('xMotivo', 'Empresa não encontrada para atualização fiscal');

      result := LJSONObject;
      exit;
    end;

    id_empresa := qryLstempresa_env.FieldByName('id').AsInteger;

    qrycons.close;
    qrycons.sql.Clear;
    qrycons.sql.Add('select * from config');
    qrycons.open;

    local_config := qrycons.FieldByName('diretorio_app').AsString;

    // Substitua 'base64Data' pelo seu certificado em formato Base64
    base64Data := JsonRaiz.Get('lcertificado_digital',''); //GetValue<string>('certificado_digital', '');

    caminho_dir :=  Kernel_DiretorioBarras(local_config) +
      'certificados\' + id_empresa.ToString + '\';

    if not DirectoryExists(caminho_dir) then
      ForceDirectories(caminho_dir);

    // Substitua 'pfxFilePath' pelo caminho desejado para o arquivo PFX
    caminho_cert := cnpj + '.pfx';
    pfxFilePath :=  caminho_dir + caminho_cert;

    // Converter Base64 para PFX
    //Base64ToPFX(base64Data, pfxFilePath);

    qryCadEmpresa.sql.Clear;
    qryCadEmpresa.sql.Add('select * from empresa where id=:id ');
    qryCadEmpresa.ParamByName('id').AsInteger := id_empresa;
    qryCadEmpresa.open;
    qryCadEmpresa.edit;

    qryCadEmpresa.FieldByName('id_ambiente').AsInteger :=
      JsonRaiz.Get('id_ambiente');   //GetValue<integer>('id_ambiente', 0);
    qryCadEmpresa.FieldByName('local_instalacao').AsInteger :=
      JsonRaiz.Get('local_instalacao'); //GetValue<integer>('local_instalacao', 0);

    qryCadEmpresa.FieldByName('senha_certificado').AsString :=
      JsonRaiz.Get('senha_certificado'); //GetValue<String>('senha_certificado', '');
    qryCadEmpresa.FieldByName('certificado_digital').AsString := caminho_cert;

    qryCadEmpresa.FieldByName('id_csc_homologacao').AsString :=
      JsonRaiz.Get('id_csc_homologacao'); //GetValue<String>('id_csc_homologacao', '');
    qryCadEmpresa.FieldByName('csc_homologacao').AsString :=
      JsonRaiz.Get('csc_homologacao'); //GetValue<String>('csc_homologacao', '');

    qryCadEmpresa.FieldByName('id_csc_producao').AsString :=
      JsonRaiz.Get('id_csc_producao',''); //GetValue<String>('id_csc_producao', '');
    qryCadEmpresa.FieldByName('csc_prod_producao').AsString :=
      JsonRaiz.Get('csc_prod_producao'); //GetValue<String>('csc_prod_producao', '');

    qryCadEmpresa.Post;

    // se for novo pega o id gerado
    if id_empresa = 0 then
    BEGIN
      qryLstempresa_env.close;
      qryLstempresa_env.sql.Clear;
      qryLstempresa_env.sql.Add
        ('select * from empresa where cpf_cnpj=:cpf_cnpj ' +
        ' and local_instalacao=:local_instalacao');
      qryLstempresa_env.ParamByName('cpf_cnpj').AsString := cnpj;
      qryLstempresa_env.ParamByName('local_instalacao').AsInteger :=
        local_instalacao;
      qryLstempresa_env.open;

      // id da empresa cadastrada
      id_empresa := qryLstempresa_env.FieldByName('id').AsInteger;
    END;

    try
      LJSONObject := TJSONObject.Create;
      LJSONObject.Add('id_empresa', id_empresa);
      LJSONObject.Add('Status', 100);

      if id_empresa > 0 then
        LJSONObject.Add('xMotivo', 'Empresa atualizada com sucesso')
      else
        LJSONObject.Add('xMotivo', 'Empresa cadastrada com sucesso');

      result := LJSONObject;

    except

      on ex: Exception do
      begin
        LJSONObject := TJSONObject.Create;
        LJSONObject.Add('Status', 500);
        LJSONObject.Add('xMotivo', ex.Message);

        result := LJSONObject;
      end;

    end;

  finally
    qryLstempresa_env.Free;
    qryCadEmpresa.Free;
    qrycons.Free;
  end;
end;

function TdmPrincipal.cadastra_empresa(JsonRaiz: TJSONObject): TJSONObject;
var
  retorno: Boolean;
  LJSONObject: TJSONObject;
  qryCadEmpresa, qryLstempresa_env, qrycons: TZQuery;
  id_empresa: integer;
  local_instalacao: integer;
  cnpj, local_config, caminho_dir: string;

  caminho_cert, base64Data, arquivo_logo: string;
begin

  try

    if not conecta_banco then
    begin
      LJSONObject := TJSONObject.Create;
      LJSONObject.Add('Status', '500');
      LJSONObject.Add('xMotivo', 'Falha de conexão com o banco de dados');

      result := LJSONObject;
      exit;
    end;

    cnpj := JsonRaiz.Get('cnpj'); //GetValue<string>('cnpj', '');
    local_instalacao := JsonRaiz.Get('local_instalacao', 1);      //GetValue<integer>('local_instalacao', 1);

    qryLstempresa_env := TZQuery.Create(nil);
    qryLstempresa_env.Connection := Conn;

    qrycons := TZQuery.Create(nil);
    qrycons.Connection := Conn;

    qryCadEmpresa := TZQuery.Create(nil);
    qryCadEmpresa.Connection := Conn;

    qryLstempresa_env.close;
    qryLstempresa_env.sql.Clear;
    qryLstempresa_env.sql.Add('select * from empresa where cpf_cnpj=:cpf_cnpj '
      + ' and local_instalacao=:local_instalacao');
    qryLstempresa_env.ParamByName('cpf_cnpj').AsString := cnpj;
    qryLstempresa_env.ParamByName('local_instalacao').AsInteger :=
      local_instalacao;
    qryLstempresa_env.open;

    if not qryLstempresa_env.IsEmpty then
      id_empresa := qryLstempresa_env.FieldByName('id').AsInteger
    else
      id_empresa := 0;

    qrycons.close;
    qrycons.sql.Clear;
    qrycons.sql.Add('select * from config');
    qrycons.open;

    local_config := qrycons.FieldByName('diretorio_app').AsString;

    qryCadEmpresa.sql.Clear;
    qryCadEmpresa.sql.Add('select * from empresa where id=:id ');
    if id_empresa > 0 then
      qryCadEmpresa.ParamByName('id').AsInteger := id_empresa
    else
      qryCadEmpresa.ParamByName('id').AsInteger := -1;
    qryCadEmpresa.open;

    if qryCadEmpresa.IsEmpty then
      qryCadEmpresa.Append
    else
      qryCadEmpresa.edit;

    qryCadEmpresa.FieldByName('id_system_unit').AsInteger := 1;
    qryCadEmpresa.FieldByName('id_ambiente').AsInteger := 2; // inicia em homologação
    qryCadEmpresa.FieldByName('numero').AsInteger :=
      JsonRaiz.Get('numero'); //GetValue<integer>('numero', 0);
    qryCadEmpresa.FieldByName('local_instalacao').AsInteger :=
      JsonRaiz.Get('local_instalacao'); //GetValue<integer>('local_instalacao', 0);

    qryCadEmpresa.FieldByName('cpf_cnpj').AsString :=
      JsonRaiz.Get('cnpj');  //GetValue<String>('cnpj', '');
    qryCadEmpresa.FieldByName('email').AsString :=
      JsonRaiz.Get('email');  //GetValue<String>('email', '');
    qryCadEmpresa.FieldByName('razao_social').AsString :=
      JsonRaiz.Get('razao_social');  //GetValue<String>('razao_social', '');
    qryCadEmpresa.FieldByName('fantasia').AsString :=
      JsonRaiz.Get('fantasia');    //GetValue<String>('fantasia', '');
    qryCadEmpresa.FieldByName('logradouro').AsString :=
      JsonRaiz.Get('logradouro');    //GetValue<String>('logradouro', '');
    qryCadEmpresa.FieldByName('uf').AsString :=
      JsonRaiz.Get('uf');     //GetValue<String>('uf', '');

    base64Data :=  JsonRaiz.Get('logo', '');

    caminho_dir :=  Kernel_DiretorioBarras(local_config) +
      'logo\' + id_empresa.ToString ;

    if not DirectoryExists(caminho_dir ) then
      ForceDirectories(caminho_dir );

    //SalvarTextoEmArquivo(base64Data, caminho_dir + 'Arquivo.txt');

    //arquivo_logo := Base64ToJPEG(base64Data, caminho_dir);

    if arquivo_logo <> '' then
      qryCadEmpresa.FieldByName('logo').AsString := arquivo_logo;

    qryCadEmpresa.Post;

    // se for novo pega o id gerado
    if id_empresa = 0 then
    BEGIN
      qryLstempresa_env.close;
      qryLstempresa_env.sql.Clear;
      qryLstempresa_env.sql.Add
        ('select * from empresa where cpf_cnpj=:cpf_cnpj ' +
        ' and local_instalacao=:local_instalacao');
      qryLstempresa_env.ParamByName('cpf_cnpj').AsString := cnpj;
      qryLstempresa_env.ParamByName('local_instalacao').AsInteger :=
        local_instalacao;
      qryLstempresa_env.open;

      // id da empresa cadastrada
      id_empresa := qryLstempresa_env.FieldByName('id').AsInteger;
    END;

    try
      LJSONObject := TJSONObject.Create;
      LJSONObject.Add('id_empresa', id_empresa);
      LJSONObject.Add('Status',100);

      if id_empresa > 0 then
        LJSONObject.Add('xMotivo', 'Empresa atualizada com sucesso')
      else
        LJSONObject.Add('xMotivo', 'Empresa cadastrada com sucesso');

      result := LJSONObject;

    except

      on ex: Exception do
      begin
        LJSONObject := TJSONObject.Create;
        LJSONObject.Add('Status', 500);
        LJSONObject.Add('xMotivo', ex.Message);

        result := LJSONObject;
      end;

    end;

  finally
    qryLstempresa_env.Free;
    qryCadEmpresa.Free;
    qrycons.Free;
  end;

end;

procedure TdmPrincipal.Libera_query_memoria(query: tzquery);
begin
  if Assigned(query) then
    query.Free;
end;

end.
