# apidev_nfe
Projeto de uma api fiscal em lazarus nf-e, nfc-e, nfs-e

Criação de uma api gratuita desenvolvida em Lazarus
Objetivo e criar uma API que rode em Linux usando o cgi do Lazarus.

Lazarus IDE
https://www.lazarus-ide.org/

Componentes

Para geração do xml, assinatura, envio para sefaz estamos utilizando o acbr
https://projetoacbr.com.br/sobre/

Para criação do servidor de api utilizamos os componentes Horse
https://github.com/HashLoad/horse

Conexão com Banco de dados
ZeosLibs
https://sourceforge.net/projects/zeoslib/

Projeto demo
Criado em PHP com adiantframework open source em php
https://adiantiframework.com.br/

Para agilizar o desenvolvimento do Projeto em PHP utilizarei uma IDE online Paga chamada MAD Builder
https://madbuilder.com.br/home

Outros demos podem ser criados em outras linguagens como contribuição

Exemplos de uso da api

Consulta Status do Serviço
http://localhost:9001/NFCe/consulta/statusServico

Body json

{
    "cpf_cnpj" : "11229442xxxxx",
    "autorizador" : "AM"
}




