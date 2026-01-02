/*  
---------------------------------------------------------------------------------------------------------------------------------
    COMENTADO POR TEMPO INDETERMINADO POIS A CRIAÇÃO DE CONTRATO NÃO SERÁ MAIS FEITA
    NO SALESFORCE, POIS AGORA ISSO É FEITO NO SAP SENDO NECESSÁRIO APENAS O ENVIO
    DO LINK DO SALESFORCE PARA NIVELLO
*/

@isTest
public with sharing class IntegracaoNivelloContratoTest {

    // //Classe de testes da classe IntegracaoNivelloContrato

    // private static final String ID_POSITIVO = '1234567890';
    // private static final String ID_NEGATIVO = '0000000000';

    // //Teste que simula operação bem sucedida de envio de contrato
    // @isTest
    // static void testeEnvioContratoPositivo(){

    //     Test.setMock(HttpCalloutMock.class, new IntegracaoEnvioContratoNivelloMock());

    //     Opportunity opp = (Opportunity) TestFactory.createSObject(new Opportunity(
    //         IdVirtualOffice__c = ID_POSITIVO
    //     ), true);

    //     insert criarArquivo(opp.Id);

    //     //Fechar a oportunidade para acionar a integração de envio de contrato
    //     test.startTest();
    //         opp.StageName = 'Fechado';
    //         update opp;
    //     test.stopTest();
    // }

    // //Objetivo: criar um arquivo de contrato simulado
    // static ContentVersion criarArquivo(Id idOportunidadeVinculada){

    //     String conteudo = 'CONTEUDO ARQUIVO CONTRATO';
    
    //     ContentVersion cv = new ContentVersion();
    //     cv.ContentLocation        = 'S';
    //     cv.VersionData            = EncodingUtil.base64Decode(conteudo);
    //     cv.Title                  = 'TITULO_ARQUIVO';
    //     cv.PathOnClient           = 'ALGUM_CAMINHO';
    //     cv.FirstPublishLocationId = idOportunidadeVinculada;

    //     return cv;
    // }

    // public class IntegracaoEnvioContratoNivelloMock implements HttpCalloutMock{

    //     public HTTPResponse respond(HTTPRequest req) {
            
    //         HTTPResponse resposta = new HTTPResponse();
    //         IntegracaoNivelloContrato.EnvioContratoRequest requisicao = 
    //             (IntegracaoNivelloContrato.EnvioContratoRequest) JSON.deserialize(req.getBody(), IntegracaoNivelloContrato.EnvioContratoRequest.class);

    //         if(requisicao.id == ID_POSITIVO){
    //             //TODO: criar resposta positiva
    //         }
    //         else if(requisicao.id == ID_NEGATIVO){
    //             //TODO: criar resposta negativa
    //         }

    //         return resposta;
    //     }
    // }

    // public class IntegracaoAceiteContratoNivelloMock implements HttpCalloutMock{

    //     public HTTPResponse respond(HTTPRequest req) {
            
    //         HTTPResponse resposta = new HTTPResponse();
    //         IntegracaoNivelloContrato.AceiteContratoRequest requisicao = 
    //             (IntegracaoNivelloContrato.AceiteContratoRequest) JSON.deserialize(req.getBody(), IntegracaoNivelloContrato.AceiteContratoRequest.class);

    //         if(requisicao.id == ID_POSITIVO){
    //             //TODO: criar resposta positiva
    //         }
    //         else if(requisicao.id == ID_NEGATIVO){
    //             //TODO: criar resposta negativa
    //         }

    //         return resposta;
    //     }
    // }
}