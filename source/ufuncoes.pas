unit UFuncoes;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, fpjson, pcnConversaoNFe, pcnAuxiliar, pcnConversao,
   ACBrUtil.Strings, ACBrUtil.Base, ACBrDFeSSL, DateUtils, base64,
  strutils, paszlib, ZipUtils, Zipper, jsonparser;

type
 Tipo_arquivo  = (taXML, taPDF, taZIP);
 Tipo_XML  = (tp_xml_autorizado, tp_xml_gerado,tp_xml_cancelado);
 TApiModeloDF = (apmNFe, apmNFCe, apmNFSe);
 TProdutoServico = (tpProduto, tpServico);

  function Retorna_Modelo(modelo : TApiModeloDF ) : integer;
  function retorna_fuso_horario_por_uf(uf : string):string;
  function Kernel_RetornaDataFuso(Data: Tdatetime; UF: string):  Tdatetime;
  function Kernel_RetornaData_servidor():  Tdatetime;
  function RetornoStatusEnvio(iretorno: integer): Boolean;
  function Remove_Caracteres_IvalidosString(Texto: string): string;
  function RemoverMascara(const Texto: string): integer;
  function formatadata_json(data: string): TDate;

  function ParseISO8601DateTime(const ISO8601Str: string): TDateTime;

  function Retorna_tipo_Pagamento(indicador : integer): TpcnIndicadorPagamento;

  function Retorna_Indicador_Destino(indicador : integer): TpcnDestinoOperacao;
  function Retorna_finalidade_nf(finalidade : integer): TpcnFinalidadeNFe;
  function Retorna_Indicador_presenca(indicador : integer): TpcnPresencaComprador;
  function Retorna_Intermediador(indicador : integer): TindIntermed;
  function Retorna_crt_empresa(indicador : integer): TpcnCRT ;
  function Retorna_crt_empresa_Servico(indicador: integer): TpcnRegTribISSQN;
  function Retorna_indicador_escala(indicador : string): TpcnIndEscala ;
  function Retorna_Origem_mercadoria(indicador : integer): TpcnOrigemMercadoria ;
  function Retorna_CST(cst: string): TpcnCSTIcms;
  function Retorna_ModalidadeBC(modbc: integer): TpcnDeterminacaoBaseIcms;
  function Retorna_ModalidadeBCST(modbc: integer): TpcnDeterminacaoBaseIcmsST;
  function retorna_motivo_icms_desonerado(
    mov_icms_desonerado: integer): TpcnMotivoDesoneracaoICMS;
  function Retorna_CSOSN(CSOSN: string): TpcnCSOSNIcms;
  function Retorna_IPI(IPI: string): TpcnCstIpi;
  function Retorna_PIS(pis: string): TpcnCstPis;
  function Retorna_COFINS(cofins: string): TpcnCstCofins;
  function Retorna_Tipo_Frete(TIPO_MOD_FRETE: integer): TpcnModalidadeFrete;
  function Retorna_FormaPagamento(cdgrupo: integer): TpcnFormaPagamento;
  function Retorna_FormaPagamento_string(codigo: TpcnFormaPagamento ): string;
  Function Separa_chaveNFe(chave: string): string;
  function Formata_DataUTC(Data: TDateTime; codigouf : integer): string;
  function retornaLinkConsulta(ambiente : TpcnTipoAmbiente ;ufcodigo: integer): string ;
  function Kernel_DiretorioBarras(Folder: string): string ;

  function AnsiIndexStr(const Value: string; const Values: array of string): Integer;


  // caminho raiz de emissçao
  function Retorna_diretorio_raiz_completo(caminho: string; id_empresa : integer;
     ModeloDF: TApiModeloDF ): string;

  // funcoes para caminho e diretorio
  function Retorna_diretorio_completo_ate_xmlpdf(caminho: string; id_empresa : integer;
    tipo_arquivo : Tipo_arquivo; ModeloDF: TApiModeloDF ): string;

  function Retorna_pasta_diretorio_zip(caminho: string; id_empresa, ano, mes : integer;
    ModeloDF: TApiModeloDF; tppasta : Tipo_arquivo): string;

  function Retorna_caminho_completo_xml(caminho, chave_acesso: string;
    id_empresa : integer; ModeloDF: TApiModeloDF; Tp_xml : Tipo_XML): string;
  function Retorna_caminho_completo_pdf(caminho, chave_acesso: string;
    id_empresa : integer; ModeloDF: TApiModeloDF): string;

  function Retorna_anomes(): string;

  function StreamToBase64(AInputStream: TStream): string;
  function Base64ToStream(const ABase64:string; AOutStream: TStream; const AStrict: Boolean=false):Boolean;
  function Base64ToFile(const Base64, AFile: String): boolean;
  function FileToBase64(const AFile: String): string;

  function SubstituirTextoCaminho(const caminhoOriginal, textoSubstituir, substituicao: string): string;

  //procedure Base64ToPFX(base64Data: string; const pfxFilePath: string);
  function Retorna_nome_pasta_xml_gerado(tipo_arquivo : Tipo_XML) : string;

  procedure SaveJSONToFile(const FileName: string; JSON: TJSONObject);
  procedure SalvarTextoEmArquivo(const texto, arquivo: string);
  // salva a imagem que veio em base64
  //function Base64ToJPEG(base64String, fileName: string): string;
  function CopiarTextoAposVirgula(const texto: string): string;
  function CopiarTextoAntesVirgula(const texto: string): string;
  function IdentificarTipoImagem(const texto: string): string;
  function CopiarValorEntre(const texto, inicio, fim: string): string;
  function CapitalizarFrases(const texto: string): string;
  procedure Remove(const Dir: string);
  function Copy_File(const SourcePath, DestPath: string): boolean;
  procedure ZipDirectoryContents(const DestFile, SourceDir: string);

 // function GetJsonValue(const jsonValue: TJSONValue ) : Variant;



implementation

function Copy_File(const SourcePath, DestPath: string): boolean;
begin

end;

procedure ZipDirectoryContents(const DestFile, SourceDir: string);
var
  ZipFile: TZipper;
  SearchRec: TSearchRec;
  FileStream: TFileStream;
begin
  ZipFile := TZipper.Create;
  try
    if FindFirst(SourceDir + PathDelim + '*', faAnyFile, SearchRec) = 0 then
    begin
      repeat
        if (SearchRec.Attr and faDirectory) = 0 then
        begin
          FileStream := TFileStream.Create(SourceDir + PathDelim + SearchRec.Name, fmOpenRead);
          try
            ZipFile.Entries.AddFileEntry(FileStream, SearchRec.Name);
          finally
            FileStream.Free;
          end;
        end;
      until FindNext(SearchRec) <> 0;
      FindClose(SearchRec);
    end;
    ZipFile.SaveToFile(DestFile);
  finally
    ZipFile.Free;
  end;
end;



procedure Remove(const Dir: string);
var
  Result: TSearchRec;
begin
  if FindFirst(Dir + '\*', faAnyFile, Result) = 0 then
  begin
    Try
      repeat
        if (Result.Attr and faDirectory) = faDirectory then
        begin
          if (Result.Name <> '.') and (Result.Name <> '..') then
            Remove(Dir + '\' + Result.Name)
        end
        else if not DeleteFile(pwidechar((Dir + '\' + Result.Name))) then
          RaiseLastOSError;
      until FindNext(Result) <> 0;
    Finally
      FindClose(Result);
    End;
  end;

 { if not RemoveDir(Dir) then
    RaiseLastOSError;   }
end;

function CapitalizarFrases(const texto: string): string;
var
  i: Integer;
  maiuscula: Boolean;
begin
  Result := ''; // Inicializa a string Result
  maiuscula := True; // Inicialmente definimos maiúscula como verdadeiro para a primeira letra

  // Iteramos por cada caractere no texto
  for i := 1 to Length(texto) do
  begin
    if maiuscula and (texto[i] in ['a'..'z', 'A'..'Z']) then
    begin
      Result := Result + UpCase(texto[i]); // Converte para maiúscula
      maiuscula := False; // Definimos para falso para evitar mais mudanças nesta frase
    end
    else
    begin
      Result := Result + texto[i];
      // Se encontramos um ponto, interrogação ou exclamação, definimos para verdadeiro
      // para a próxima letra ser maiúscula
      if texto[i] in ['.', '?', '!'] then
        maiuscula := True;
    end;
  end;
end;

function CopiarValorEntre(const texto, inicio, fim: string): string;
var
  posicaoInicio, posicaoFim: Integer;
begin
  // Encontrar a posição do início
  posicaoInicio := Pos(inicio, texto);

  // Se o início não foi encontrado, retornar uma string vazia
  if posicaoInicio = 0 then
    Exit('');

  // Encontrar a posição do fim
  posicaoFim := PosEx(fim, texto, posicaoInicio + Length(inicio));

  // Se o fim não foi encontrado, retornar uma string vazia
  if posicaoFim = 0 then
    Exit('');

  // Copiar o valor entre o início e o fim
  Result := Copy(texto, posicaoInicio + Length(inicio), posicaoFim - posicaoInicio - Length(inicio));
end;

function IdentificarTipoImagem(const texto: string): string;
var
  posicaoTipo: Integer;
  tipo: string;
begin
  // Encontrar a posição do texto "data:image/"
  posicaoTipo := Pos('data:image/', texto);

  // Se "data:image/" foi encontrado
  if posicaoTipo > 0 then
  begin
    // Copiar o tipo de imagem após "data:image/"
    //tipo := Copy(texto, posicaoTipo + Length('data:image/'), 4); // Ajuste para pegar 4 caracteres (jpeg ou png)

    tipo := CopiarValorEntre(texto, '/', ';');

    // Verificar se o tipo de imagem é jpeg ou png
    if (tipo = 'jpeg') or (tipo = 'png') then
      Result := tipo
    else
      Result := 'Desconhecido';
  end
  else
    Result := 'Não começa com "data:image/"';
end;

function CopiarTextoAposVirgula(const texto: string): string;
var
  posicaoVirgula: Integer;
begin
  // Encontrar a posição da vírgula
  posicaoVirgula := Pos(',', texto);

  // Se a vírgula não foi encontrada, retornar uma string vazia
  if posicaoVirgula = 0 then
    Result := ''
  else
    // Copiar o texto após a vírgula
    Result := Copy(texto, posicaoVirgula + 1, Length(texto) - posicaoVirgula);
end;

function CopiarTextoAntesVirgula(const texto: string): string;
var
  posicaoVirgula: Integer;
begin
  // Encontrar a posição da vírgula
  posicaoVirgula := Pos(',', texto);

  // Se a vírgula não foi encontrada, retornar a string original
  if posicaoVirgula = 0 then
    Result := texto
  else
    // Copiar o texto antes da vírgula
    Result := Copy(texto, 1, posicaoVirgula - 1);
end;




function AnsiIndexStr(const Value: string; const Values: array of string): Integer;
var
  I: Integer;
begin
  Result := -1;  // Retorna -1 se a string não for encontrada
  for I := Low(Values) to High(Values) do
  begin
    if CompareStr(Value, Values[I]) = 0 then
    begin
      Result := I;
      Exit;
    end;
  end;
end;

function Retorna_Modelo(modelo : TApiModeloDF ) : integer;
begin
  if modelo = apmNFe then
    Result := 55;
  if modelo = apmNFCe then
    Result := 65;
end;

function retorna_fuso_horario_por_uf(uf : string): string;
begin

  // Mapeie as UFs para os fusos horários correspondentes em formato numérico
  case AnsiIndexStr(uf, ['AC', 'AL', 'AP','AM', 'BA','CE','DF', 'ES','GO',
   'MA', 'MT', 'MS', 'MG','PA', 'PB', 'PR','PE','PI','RJ', 'RN', 'RS', 'RO', 'RR',
     'SC', 'SP' ,'SE','TO'  ]) of
    0: Result := '-05:00';   // Acre
    1: Result := '-03:00';   // Alagoas
    2: Result := '-03:00';   // Amapá
    3: Result := '-04:00';   // Amazonas
    4: Result := '-03:00';   // Bahia
    5: Result := '-03:00';   // Ceará
    6: Result := '-03:00';   // Distrito Federal (Brasília)
    7 : Result := '-03:00';   // Espírito Santo
    8: Result := '-03:00';   // Goiás
    9: Result := '-03:00';   // Maranhão
    10: Result := '-04:00';   // Mato Grosso
    11: Result := '-04:00';   // Mato Grosso do Sul
    12 : Result := '-03:00';   // Minas Gerais
    13 : Result := '-03:00';   // Pará
    14 : Result := '-03:00';   // Paraíba
    15 : Result := '-03:00';   // Paraná
    16 : Result := '-03:00';   // Pernambuco
    17 : Result := '-03:00';   // Piauí
    18 : Result := '-03:00';   // Rio de Janeiro
    19 : Result := '-03:00';   // Rio Grande do Norte
    20 : Result := '-03:00';   // Rio Grande do Sul
    21 : Result := '-04:00';   // Rondônia
    22 : Result := '-04:00';   // Roraima
    23 : Result := '-03:00';   // Santa Catarina
    24 : Result := '-03:00';   // São Paulo
    25: Result := '-03:00';   // Sergipe
    26 : Result := '-03:00';   // Tocantins
  else
    Result := '-04:00'; // UF não encontrada ou inválida
  end;
end;

function Kernel_RetornaDataFuso(Data: Tdatetime; UF: string): Tdatetime;

var
  strFuso, strFusoSefaz: string;
begin

  strFuso := retorna_fuso_horario_por_uf(uf);
  strFusoSefaz := retorna_fuso_horario_por_uf(uf);

  if (strFusoSefaz <> strFuso) then
  begin
    if (strFuso = '-02:00') and (strFusoSefaz = '-03:00') then
    begin
      Result := IncHour(Data, -1);
    end
    else if (strFuso = '-02:00') and (strFusoSefaz = '-04:00') then
    begin
      Result := IncHour(Data, -2);
    end
    else if (strFuso = '-03:00') and (strFusoSefaz = '-02:00') then
    begin
      Result := IncHour(Data);
    end
    else if (strFuso = '-03:00') and (strFusoSefaz = '-04:00') then
    begin
      Result := IncHour(Data, -1);
    end
    else if (strFuso = '-04:00') and (strFusoSefaz = '-02:00') then
    begin
      Result := IncHour(Data, 2);
    end
    else if (strFuso = '-04:00') and (strFusoSefaz = '-03:00') then
    begin
      Result := IncHour(Data);
    end;
  end
  else
    Result := Data;
end;

function Kernel_RetornaData_servidor():  Tdatetime;
begin
  Result := Date;
end;

function RetornoStatusEnvio(iretorno: integer): Boolean;
begin
  result := False;

  // Retrorna Ok se os retornos padrões de retorno ok
  if iretorno = 150 then // Autorizado o uso da NF-e, autorizacao fora de prazo
    result := True;

  // Retrorna Ok se os retornos padrões de retorno ok
  if iretorno = 151 then // Cancelamento de NF-e homologado fora de prazo
    result := True;

  // Retrorna Ok se os retornos padrões de retorno ok
  if iretorno = 100 then // Autorizado o uso da NF-e
    result := True;

  if iretorno = 101 then // Cancelado o uso da NF-e Homoloado
    result := True;

  if iretorno = 102 then // Inutilização de número homologado
    result := True;

  if iretorno = 103 then // Lote recebido com sucesso
    result := True;

  if iretorno = 104 then // Lote processado
    result := True;

  if iretorno = 105 then // Lote em processamento
    result := True;

  if iretorno = 107 then // Serviço em Operação
    result := True;

  if iretorno = 124 then // Serviço em Operação
    result := True;

  // cancelamento de evento homologado
  if iretorno = 135 then // Evento Registrado e viculado a NFe
    result := True;

end;

function Remove_Caracteres_IvalidosString(Texto: string): string;
var
  TamanhoTexto, i: Integer;
  CharToCheck: string;
begin
  // Remove aspas simples
  while Pos(Chr(39), Texto) > 0 do
    Delete(Texto, Pos(Chr(39), Texto), 1);

  // Remove aspas duplas
  while Pos('"', Texto) > 0 do
    Delete(Texto, Pos('"', Texto), 1);

  // Remove espaços extras no início e fim
  Texto := Trim(Texto);
  TamanhoTexto := Length(Texto);

  for i := 1 to TamanhoTexto do
  begin
    // Verifique o caractere como string
    CharToCheck := Texto[i];

    // Se o caractere não estiver na lista de permitidos
    if Pos(CharToCheck, ' 0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ()+=-/\') = 0 then
    begin
      case CharToCheck of
        'á', 'Á', 'à', 'À', 'â', 'Â', 'ä', 'Ä', 'ã', 'Ã': Texto[i] := 'A';
        'é', 'É', 'è', 'È', 'ê', 'Ê', 'ë', 'Ë': Texto[i] := 'E';
        'í', 'Í', 'ì', 'Ì', 'î', 'Î', 'ï', 'Ï': Texto[i] := 'I';
        'ó', 'Ó', 'ò', 'Ò', 'ô', 'Ô', 'ö', 'Ö', 'õ', 'Õ': Texto[i] := 'O';
        'ú', 'Ú', 'ù', 'Ù', 'û', 'Û', 'ü', 'Ü': Texto[i] := 'U';
        'ç', 'Ç': Texto[i] := 'C';
        'ñ', 'Ñ': Texto[i] := 'N';
        '&': Texto[i] := 'E';
      else
        Texto[i] := ' '; // Substitui caracteres não mapeados por espaço
      end;
    end;
  end;

  Result := AnsiUpperCase(Texto); // Retorna o texto em maiúsculas
end;

function RemoverMascara(const Texto: string): integer;
var
  i: Integer;
  Resultado: string;
begin
  Resultado := '';
  for i := 1 to Length(Texto) do
  begin
    // Verifica se o caractere atual é um dígito
    if Texto[i] in ['0'..'9'] then
    begin
      // Adiciona o dígito ao resultado
      Resultado := Resultado + Texto[i];
    end;
  end;

  Result := Resultado.ToInteger();
end;

function formatadata_json(data: string): TDate;
var
  DateStr: string;
  nova_data: TDateTime;
  FormatSettings: TFormatSettings;
begin
  FormatSettings.ShortDateFormat := 'dd-mm-yyyy:hh-mm-ss';
  FormatSettings.DateSeparator := '-';

  DateStr := data;
  //nova_data := ParseISO8601DateTime(DateStr);
  nova_data := now;
  result := nova_data;

//  if TryStrToDate(DateStr, nova_data, FormatSettings) then
//  begin
//    result := nova_data;
//  end
// else
//  begin
//    nova_data :=  EncodeDate(
//    StrToInt(Copy(DateStr, 1, 4)),   // Ano
//    StrToInt(Copy(DateStr, 6, 2)),   // Mês
//    StrToInt(Copy(DateStr, 9, 2))  );
//    result := nova_data;
//  end;
  //:= StrToDate(FormatDateTime('dd/mm/yyyy', data));
end;

procedure SaveJSONToFile(const FileName: string; JSON: TJSONObject);
var
  JsonString: string;
  StringList: TStringList;
begin
  // Convertendo o JSON para uma string
  JsonString := JSON.ToString;

  // Criando um TStringList e adicionando a string JSON
  StringList := TStringList.Create;
  try
    StringList.Text := JsonString;

    // Salvando a string list em um arquivo de texto
    StringList.SaveToFile(FileName);
  finally
    StringList.Free;
  end;
end;

function ParseISO8601DateTime(const ISO8601Str: string): TDateTime;
var
  Year, Month, Day, Hour, Min, Sec, MSec: Word;
begin
  // Extrair partes da data e hora
  Year := StrToInt(Copy(ISO8601Str, 1, 4));
  Month := StrToInt(Copy(ISO8601Str, 6, 2));
  Day := StrToInt(Copy(ISO8601Str, 9, 2));
  Hour := StrToInt(Copy(ISO8601Str, 12, 2));
  Min := StrToInt(Copy(ISO8601Str, 15, 2));
  Sec := StrToInt(Copy(ISO8601Str, 18, 2));
  MSec := 0;

  // Criar TDateTime
  Result := EncodeDateTime(Year, Month, Day, Hour, Min, Sec, MSec);
end;

function Retorna_tipo_Pagamento(indicador : integer): TpcnIndicadorPagamento;
begin
  case indicador of
    0:
      result := ipVista;
    1:
      result := ipPrazo;
    2:
      result := ipOutras;
    3:
      result := ipNenhum;
  end;
end;

function Retorna_Indicador_Destino(indicador : integer): TpcnDestinoOperacao;
begin
  case indicador of
     1: result :=  doInterna;
     2 : result :=  doInterestadual;
     3 : result :=  doExterior;
  end;
end;

function Retorna_finalidade_nf(finalidade : integer): TpcnFinalidadeNFe;
begin
  case finalidade of
     1: result :=  fnNormal;
     2 : result :=  fnComplementar;
     3 : result :=  fnAjuste;
     4 : result :=  fnDevolucao;
  end;
end;

function Retorna_Indicador_presenca(indicador : integer): TpcnPresencaComprador;
begin
  case indicador of
     0: result :=  pcNao;
     1 : result :=  pcPresencial;
     2 : result :=  pcInternet;
     3 : result :=  pcTeleatendimento;
     4 : result :=  pcEntregaDomicilio;
     5 : result :=  pcPresencialForaEstabelecimento;
     9 : result :=  pcOutros;
  end;
end;

function Retorna_Intermediador(indicador : integer): TindIntermed;
begin
  case indicador of
      2 : result := iiOperacaoSemIntermediador;
      3 : result := iiOperacaoSemIntermediador;
      4 : result := iiOperacaoSemIntermediador;
      6 : result := iiOperacaoSemIntermediador;
  end;
end;

function Retorna_crt_empresa(indicador : integer): TpcnCRT ;
begin
  case indicador of
    1: result := crtSimplesNacional;
    2: result := crtSimplesExcessoReceita;
    3: result := crtRegimeNormal;
  end;
end;

function Retorna_crt_empresa_Servico(indicador: integer): TpcnRegTribISSQN;
begin
  case indicador of
    1: result := RTISSMEEPP;
    2: result := RTISSMEEPP;
    3: result:= RTISSMicroempresaMunicipal;
  end;
end;

function Retorna_Origem_mercadoria(indicador : integer): TpcnOrigemMercadoria ;
begin
  case indicador of
    0: result := oeNacional;
    1: result := oeEstrangeiraImportacaoDireta;
    2: result := oeEstrangeiraAdquiridaBrasil;
    3: result := oeNacionalConteudoImportacaoSuperior40;
    4: result := oeNacionalProcessosBasicos;
    5: result := oeNacionalConteudoImportacaoInferiorIgual40;
    6: result := oeEstrangeiraImportacaoDiretaSemSimilar;
    7: result := oeEstrangeiraAdquiridaBrasilSemSimilar;
    8: result := oeNacionalConteudoImportacaoSuperior70;
  end;

end;

function Retorna_indicador_escala(indicador : string): TpcnIndEscala ;
begin
  if indicador = 'S' then
    result := ieRelevante
   else
   result := ieNaoRelevante;
end;


function Retorna_CST(cst: string): TpcnCSTIcms;
begin
  case AnsiIndexStr(UpperCase(cst), ['00', '10', '20', '30', '40', '41', '45', '50', '51', '60', '70', '81', '90']) of
    0:
      result := cst00;
    1:
      result := cst10;
    2:
      result := cst20;
    3:
      result := cst30;
    4:
      result := cst40;
    5:
      result := cst41;
    6:
      result := cst45;
    7:
      result := cst50;
    8:
      result := cst51;
    9:
      result := cst60;
    10:
      result := cst70;
    11:
      result := cst81;
    12:
      result := cst90;
  end;
end;

function Retorna_ModalidadeBC(modbc: integer): TpcnDeterminacaoBaseIcms;
begin
  case modbc of
    0:
      result := dbiMargemValorAgregado;
    1:
      result := dbiPauta;
    2:
      result := dbiPrecoTabelado;
    3:
      result := dbiValorOperacao;
  end;
end;

function Retorna_ModalidadeBCST(modbc: integer): TpcnDeterminacaoBaseIcmsST;
begin
  case modbc of
    0:
      result := dbisPrecoTabelado;
    1:
      result := dbisListaNegativa;
    2:
      result := dbisListaPositiva;
    3:
      result := dbisListaNeutra;
    4:
      result := dbisMargemValorAgregado;
    5:
      result := dbisPauta;
    6:
      result := dbisValordaOperacao;
  end;
end;

function retorna_motivo_icms_desonerado(
  mov_icms_desonerado: integer): TpcnMotivoDesoneracaoICMS;
begin

  case mov_icms_desonerado of
    1:
      result := mdiTaxi;
    2:
      result := mdiDeficienteFisico;
    3:
      result := mdiProdutorAgropecuario;
    4:
      result :=  mdiFrotistaLocadora;
    5:
      result := mdiDiplomaticoConsular;
    6:
      result := mdiAmazoniaLivreComercio;
    7:
      result := mdiSuframa;
    8:
      result := mdiVendaOrgaosPublicos;
    9:
      result := mdiOutros;
    10:
      result := mdiDeficienteCondutor;
    11:
      result := mdiDeficienteNaoCondutor;
    12:
      result := mdiOrgaoFomento;
    13:
      result := mdiSolicitadoFisco;
  end;

end;

function Retorna_CSOSN(CSOSN: string): TpcnCSOSNIcms;
begin
  case AnsiIndexStr(UpperCase(CSOSN), ['101', '102', '103', '201', '202', '203', '300', '400', '500', '900']) of
    0:
      result := csosn101;
    1:
      result := csosn102;
    2:
      result := csosn103;
    3:
      result := csosn201;
    4:
      result := csosn202;
    5:
      result := csosn203;
    6:
      result := csosn300;
    7:
      result := csosn400;
    8:
      result := csosn500;
    9:
      result := csosn900;
  end;
end;

function Retorna_IPI(IPI: string): TpcnCstIpi;
begin

  case AnsiIndexStr(UpperCase(IPI), ['00', '01', '02', '03', '04', '05',
    '49', '50', '51', '52','53','54','55','99']) of
    0:
      result := ipi00;
    1:
      result := ipi01;
    2:
      result := ipi02;
    3:
      result := ipi03;
    4:
      result := ipi04;
    5:
      result := ipi05;
    6:
      result := ipi49;
    7:
      result := ipi50;
    8:
      result := ipi51;
    9:
      result := ipi52;
    10:
      result := ipi53;
    11:
      result := ipi54;
    12:
      result := ipi55;
    13:
      result := ipi99;
  end;

end;

function Retorna_PIS(pis: string): TpcnCstPis;
var
 codigo : integer;
begin
  codigo := strtoint(pis) ;
   case codigo of
    1:
      result := pis01;
    2:
      result := pis02;
    3:
      result := pis03;
    4:
      result := pis04;
    5:
      result := pis05;
    6:
      result := pis06;
    7:
      result := pis07;
    8:
      result := pis08;
    9:
      result := pis09;
    49:
      result := pis49;
    50:
      Result := pis50;
    51:
      Result := pis51;
    52:
      result := pis52;
    53:
      result := pis53;
    54:
      result := pis54;
    55:
      result := pis55;
    56:
      result := pis56;
    60:
      result := pis60;
    61:
      result := pis61;
    63:
      Result := pis63;
    64:
      Result := pis64;
    65:
      Result := pis65;
    66:
      Result := pis66;
    67:
      Result := pis67;
    70:
      Result := pis70;
    71:
      Result := pis71;
    72:
      Result := pis72;
    73:
      Result := pis73;
    74:
      Result := pis74;
    75:
      Result := pis75;
    98:
      Result := pis98;
    99:
      result := pis99;
  end;
end;

function Retorna_COFINS(cofins: string): TpcnCstCofins;
var
 codigo : integer;
begin
  codigo := strtoint(cofins) ;
  case codigo of
    1:
      result := cof01;
    2:
      result := cof02;
    3:
      result := cof03;
    4:
      result := cof04;
    5:
      result := cof05;
    6:
      result := cof06;
    7:
      result := cof07;
    8:
      result := cof08;
    9:
      result := cof09;
    49:
      result := cof49;
    50:
      Result := cof50;
    51:
      Result := cof51;
    52:
      result := cof52;
    53:
      result := cof53;
    54:
      result := cof54;
    55:
      result := cof55;
    56:
      result := cof56;
    60:
      result := cof60;
    61:
      result := cof61;
    63:
      Result := cof63;
    64:
      Result := cof64;
    65:
      Result := cof65;
    66:
      Result := cof66;
    67:
      Result := cof67;
    70:
      Result := cof70;
    71:
      Result := cof71;
    72:
      Result := cof72;
    73:
      Result := cof73;
    74:
      Result := cof74;
    75:
      Result := cof75;
    98:
      Result := cof98;
    99:
      result := cof99;
  end;
end;

function Retorna_Tipo_Frete(TIPO_MOD_FRETE: integer): TpcnModalidadeFrete;
begin
  case TIPO_MOD_FRETE of
    1:
      result := mfContaEmitente;
    2:
      result := mfContaDestinatario;
    3:
      result := mfContaTerceiros;
    4:
      result := mfSemFrete;
    5:
      result := mfProprioRemetente;
    6:
      result := mfProprioDestinatario;
  end;
end;

function Retorna_FormaPagamento(cdgrupo: integer): TpcnFormaPagamento;
begin
  case cdgrupo of
    1:  Result := fpDinheiro;
    2:  Result := fpCheque;
    3:  Result := fpCartaoCredito;
    4:  Result := fpCartaoDebito;
    5:  Result := fpCreditoLoja;
    10: Result := fpValeAlimentacao;
    11: Result := fpValeRefeicao;
    12: Result := fpValePresente;
    13: Result := fpValeCombustivel;
    14: Result := fpDuplicataMercantil;
    15: Result := fpBoletoBancario;
    16: Result := fpDepositoBancario;
    17: Result := fpPagamentoInstantaneo;
    18: Result := fpTransfBancario;
    19: Result := fpProgramaFidelidade;
    90: Result := fpSemPagamento;
    99: Result := fpOutro;
  else
    Result := fpOutro;
  end;
end;

function Retorna_FormaPagamento_string(codigo: TpcnFormaPagamento ): string;
begin
 case codigo of
    fpDinheiro:
      result := 'Dinheiro';
    fpCheque:
      result := 'Cheque';
    fpCartaoCredito:
      result := 'Cartao de Credito';
    fpCartaoDebito:
      result := 'Cartao de Debito';
    fpCreditoLoja:
      result := 'Credito Loja';
    fpValeAlimentacao:
      result := 'Vale Alimentacao';
    fpValeRefeicao:
      result := 'Vale Refeicao';
    fpValePresente:
      result := 'Vale Presente';
    fpValeCombustivel:
      result := 'Vale Combustivel';
    fpDuplicataMercantil:
      result := 'Duplicata Mercantil';
    fpBoletoBancario:
      result := 'Boleto Bancario';
    fpDepositoBancario:
      result := 'Deposito Bancario';
    fpPagamentoInstantaneo:
      result := 'Pagamento Instantaneo';
    fpTransfBancario:
      result := 'Transf Bancario';
    fpProgramaFidelidade:
      result := 'Programa Fidelidade';
    fpSemPagamento:
      result := 'Sem Pagamento';
    fpRegimeEspecial:
      result := 'Regime Especial';
    fpOutro:
      result := 'Outro9';

  end;

end;

function Separa_chaveNFe(chave: string): string;
begin
  if chave <> '' then
  begin
    Result := copy(chave, 1, 4) + ' ' + copy(chave, 5, 4) + ' ' +
      copy(chave, 9, 4) + ' ' + copy(chave, 13, 4) + ' ' + copy(chave, 17, 4) +
      ' ' + copy(chave, 21, 4) + ' ' + copy(chave, 25, 4) + ' ' +
      copy(chave, 29, 4) + ' ' + copy(chave, 33, 4) + ' ' + copy(chave, 37, 4) +
      ' ' + copy(chave, 41, 4) + ' ' + copy(chave, 45, 44) + ' ' +
      copy(chave, 49, 4);
  end;
end;

function Formata_DataUTC(Data: TDateTime; codigouf : integer): string;
begin
  Result := (DateTimeTodh(Data) +
    GetUTC(CodigoParaUF(codigouf), Data));
end;

function retornaLinkConsulta(ambiente : TpcnTipoAmbiente ;ufcodigo: integer): string;
begin

  case ambiente of
    taHomologacao:
      begin
        // Pega endereço de consulta publica da nfce
        case ufcodigo of
          13: // Amazonas
            Result := 'http://sistemas.sefaz.am.gov.br/nfceweb/formConsulta.do';
          14: // Roraima
            Result := 'https://www.sefaz.rr.gov.br/nfce/servlet/wp_consulta_nfce';
          51: // Mato Grosso
            Result := 'http://homologacao.sefaz.mt.gov.br/nfce/consultanfce';
          11: // Rondônia
            Result := 'http://www.nfce.sefin.ro.gov.br';
          12: // Acre
            Result := 'http://hml.sefaznet.ac.gov.br';
          21: // Maranhão
            Result := 'http://www.hom.nfce.sefaz.ma.gov.br/portal/consultarNFCe.jsp';
          24: // Rio Grande do Norte
            Result := 'http://nfce.set.rn.gov.br';
          43: // Rio Grande do Sul
            Result := 'https://www.sefaz.rs.gov.br/NFCE/NFCE-COM.aspx';
          35: // São Paulo
            Result := '';
          28: // Sergipe
            Result := 'http://www.hom.nfe.se.gov.br';
          15: // Pará
            Result := '';
          33: // Rio de Janeiro
            Result := 'http://nfce.fazenda.rj.gov.br/consulta';
        end;
      end;
    taProducao:
      begin
        // Pega endereço de consulta publica da nfce
        case ufcodigo of
          13: // Amazonas
            Result := 'http://sistemas.sefaz.am.gov.br/nfceweb/formConsulta.do';
          14: // Roraima
            Result := 'https://www.sefaz.rr.gov.br/nfce/servlet/wp_consulta_nfce';
          51: // Mato Grosso
            Result := 'http://www.sefaz.mt.gov.br/nfce/consultanfce';
          11: // Rondônia
            Result := 'http://www.nfce.sefin.ro.gov.br/consultanfce/consulta.jsp';
          12: // Acre
            Result := 'http://hml.sefaznet.ac.gov.br/nfce/qrcode?';
          21: // Maranhão
            Result := 'http://www.nfce.sefaz.ma.gov.br/portal/consultarNFCe.jsp';
          24: // Rio Grande do Norte
            Result := 'http://nfce.set.rn.gov.br';
          43: // Rio Grande do Sul
            Result := 'https://www.sefaz.rs.gov.br/NFCE/NFCE-COM.aspx';
          35: // São Paulo
            Result := '';
          28: // Sergipe
            Result := 'http://www.nfce.se.gov.br/portal/consultarNFCe.jsp';
          15: // Pará
            Result := 'https://appnfc.sefa.pa.gov.br/portal/view/consultas/nfce/nfceForm.seam';
          33: // Rio de Janeiro
            Result := 'http://nfce.fazenda.rj.gov.br/consulta';
        end;
      end;
  end;

end;

function Kernel_DiretorioBarras(Folder: string): string;
begin
  if Trim(Folder) <> '' then
    // Se o diretorio nao tiver uma barra no final coloca
    if Folder[Length(Folder)] <> '/' then
      Kernel_DiretorioBarras := Folder + '/'
    else
      Kernel_DiretorioBarras := Folder;
end;

function Retorna_diretorio_raiz_completo(caminho: string; id_empresa : integer;
     ModeloDF: TApiModeloDF ): string;
 var
 diretorio, modelo : string;
begin
  if ModeloDF = apmNFe then
    modelo := 'NFe';
  if ModeloDF = apmNFCe then
   modelo := 'NFCe';
  if ModeloDF = apmNFSe then
   modelo := 'NFSe';

   result := Kernel_DiretorioBarras(caminho) + modelo +'\' + id_empresa.ToString +'\' +  Retorna_anomes + '\';

end;

function Retorna_diretorio_completo_ate_xmlpdf(caminho: string; id_empresa : integer;
  tipo_arquivo : Tipo_arquivo ; ModeloDF: TApiModeloDF  ): string;
 var
 tipo_pasta, diretorio : string;
begin

  if tipo_arquivo = taXML then
    tipo_pasta := 'xml'
   else
    tipo_pasta  := 'pdf';

  diretorio := Retorna_diretorio_raiz_completo(caminho, id_empresa, ModeloDF) + tipo_pasta + '\';

  if not DirectoryExists(diretorio) then
    ForceDirectories(diretorio);

  result := diretorio;
 end;

function Retorna_pasta_diretorio_zip(caminho: string; id_empresa, ano, mes : integer;
    ModeloDF: TApiModeloDF; tppasta : Tipo_arquivo): string;
 var
 diretorio, modelo, tipo_pasta : string;
begin

  if ModeloDF = apmNFe then
    modelo := 'NFe'
   else
   modelo := 'NFCe';

  if tppasta = taXML then
    tipo_pasta := 'xml'
   else
    tipo_pasta  := 'zip';


  diretorio := Kernel_DiretorioBarras(caminho) + modelo +'/' + id_empresa.ToString +'/' +
    (ano.ToString+mes.ToString) + '/'+ tipo_pasta+ '/' ;

  if not DirectoryExists(diretorio) then
    ForceDirectories(diretorio);

  result := diretorio;
end;

function Retorna_caminho_completo_xml(caminho, chave_acesso: string;
   id_empresa : integer; ModeloDF: TApiModeloDF; Tp_xml : Tipo_XML): string;
var
  caminho_xml, nome_pasta_xml : string;
begin

  nome_pasta_xml := Retorna_nome_pasta_xml_gerado(Tp_xml);

  caminho_xml := Retorna_diretorio_completo_ate_xmlpdf(caminho, id_empresa,
    taXML, ModeloDF) + '/' + nome_pasta_xml + '/' + chave_acesso + '-nfe.xml';

  result := caminho_xml;
end;

function Retorna_caminho_completo_pdf(caminho, chave_acesso: string; id_empresa : integer; ModeloDF: TApiModeloDF): string;
var
  caminho_xml : string;
begin
  caminho_xml := Retorna_diretorio_completo_ate_xmlpdf(caminho, id_empresa, tapdf, ModeloDF) + '/' + chave_acesso+ '.pdf';

  result := caminho_xml;
end;


function Retorna_anomes(): string;
 var
  mes, ano : integer;
  data : Tdatetime;
  anomes, diretorio : string;
begin
  data := now;
  ano :=  FormatDateTime('yyyy', data ).ToInteger;
  mes := FormatDateTime('mm', data ).ToInteger;;

  result := (ano.ToString+mes.ToString);
end;

function StreamToBase64(AInputStream: TStream): string;
var
  OutputStream: TStringStream;
  Encoder: TBase64EncodingStream;
begin
  Result := '';

  OutputStream := TStringStream.Create('');
  Encoder := TBase64EncodingStream.Create(OutputStream);

  try
    Encoder.CopyFrom(AInputStream, AInputStream.Size);
    Encoder.Flush;

    Result := OutputStream.DataString;
  finally
    Encoder.Free;
    OutputStream.Free;
  end;
end;

function Base64ToStream(const ABase64:string; AOutStream: TStream; const AStrict: Boolean=false):Boolean;
var
  InStream: TStringStream;
  Decoder: TBase64DecodingStream;
begin
  Result := False;
  InStream := TStringStream.Create(ABase64);
  try
    if AStrict then
      Decoder := TBase64DecodingStream.Create(InStream, bdmStrict)
    else
      Decoder := TBase64DecodingStream.Create(InStream, bdmMIME);
    try
       AOutStream.CopyFrom(Decoder, Decoder.Size);
       Result := True;
    finally
      Decoder.Free;
    end;
  finally
    InStream.Free;
  end;
end;

function Base64ToFile(const Base64, AFile: String): boolean;
var
  OutStream: TFileStream;
begin
  Result := False;
  OutStream := TFileStream.Create(AFile, fmCreate or fmShareExclusive);
  try
     Base64ToStream(Base64, OutStream);
     Result := True;
  finally
    Outstream.Free;
  end;
end;

function FileToBase64(const AFile: String): string;
var
  InputStream: TFileStream;
begin
  if not FileExists(AFile) then
    Exit('');

  InputStream := TFileStream.Create(AFile, fmOpenRead or fmShareDenyWrite);
  try
    Result := StreamToBase64(InputStream);
  finally
    InputStream.Free;
  end;
end;

function SubstituirTextoCaminho(const caminhoOriginal, textoSubstituir, substituicao: string): string;
var
  posicao: Integer;
begin
  // Procurar a posição do texto a ser substituído
  posicao := Pos(textoSubstituir, caminhoOriginal);

  // Se encontrado, realizar a substituição
  if posicao > 0 then
    Result := Copy(caminhoOriginal, 1, posicao - 1) + substituicao +
              Copy(caminhoOriginal, posicao + Length(textoSubstituir), MaxInt)
  else
    Result := caminhoOriginal;
end;


function Retorna_nome_pasta_xml_gerado(tipo_arquivo : Tipo_XML) : string;
begin
  case tipo_arquivo of
    tp_xml_autorizado : result := 'autorizado';
    tp_xml_gerado : result := 'gerado';
    tp_xml_cancelado : result := 'cancelado';
  end;

end;

procedure SalvarTextoEmArquivo(const texto, arquivo: string);
begin

    //TFile.WriteAllText(arquivo, texto);
   // ShowMessage('Texto salvo com sucesso!');

end;



end.

