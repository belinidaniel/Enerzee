@isTest
public with sharing class APIOpcoesCondicaoPagamentoTest {

    /* 
        Autor: Bruno Peixoto, JFOX
        Data: 18/10/2022
        Objetivo: testes da classe APIOpcoesCondicaoPagamento
    */
   
    //Teste positivo, com os parâmetros corretos
    @isTest
    static void testePositivo(){

        Test.setMock(HttpCalloutMock.class, new APICondPagamentoMock());

        final Integer QTD_EXISTENTES = APIOpcoesCondicaoPagamento.buscarOpcoesExistentes().size();

        RestRequest request   = new RestRequest();
        RestResponse response = new RestResponse();
        request.requestUri    = URL.getSalesforceBaseUrl().toExternalForm() + '/services/apexrest/gerenciarOpcoesCondicaoPagamento';
        request.httpMethod    = 'POST';
        request.requestBody   = Blob.valueOf(JSON.serialize(montarRequisicao(2)));

        RestContext.request  = request;
        RestContext.response = response;

        test.startTest();
            APIOpcoesCondicaoPagamento.RespostaWrapper resposta = APIOpcoesCondicaoPagamento.criarOpcoes();
        test.stopTest();

    }

    @isTest
    static void testeJSONInvalido(){

        //Setar o mock a ser usado nas chamadas de API internas
        Test.setMock(HttpCalloutMock.class, new APICondPagamentoMock());

        String body = '{{{';  //JSON inválido

        //Montar a requisição a ser feita à API
        RestRequest request   = new RestRequest();
        RestResponse response = new RestResponse();
        request.requestUri    = URL.getSalesforceBaseUrl().toExternalForm() + '/services/apexrest/gerenciarOpcoesCondicaoPagamento';
        request.httpMethod    = 'POST';
        request.requestBody   = Blob.valueOf(JSON.serialize(body));

        //Configurar a requisição no contexto
        RestContext.request  = request;
        RestContext.response = response;

        test.startTest();
            APIOpcoesCondicaoPagamento.RespostaWrapper resposta = APIOpcoesCondicaoPagamento.criarOpcoes();
        test.stopTest();

        //Avaliar o retorno da API
        System.assert(!resposta.success, 'JSON Inválido -> Retornou sucesso indevidamente.');
        System.assertEquals('JSON_INVALIDO', resposta.errors[0].errorCode, 'Código de erro retornado inválido.');

        Log__c lg = [SELECT
                        Id, Method__c
                     FROM Log__c];

        System.assertEquals('criarOpcoes - erro no JSON recebido', lg.Method__c, 'JSON Inválido -> Não gravou o log de erro corretamente.');
    }

    //Testa a validação que garante que as novas opções não sejam nulas
    @isTest
    static void testeOpcaoVazia(){

        //Setar o mock a ser usado nas chamadas de API internas
        Test.setMock(HttpCalloutMock.class, new APICondPagamentoMock());

        List<APIOpcoesCondicaoPagamento.RequisicaoWrapper> novasOpcoes = montarRequisicao(2);

        //Colocar o valor vazio
        novasOpcoes[0].valor = null;

        //Montar a requisição a ser feita à API
        RestRequest request   = new RestRequest();
        RestResponse response = new RestResponse();
        request.requestUri    = URL.getSalesforceBaseUrl().toExternalForm() + '/services/apexrest/gerenciarOpcoesCondicaoPagamento';
        request.httpMethod    = 'POST';
        request.requestBody   = Blob.valueOf(JSON.serialize(novasOpcoes));

        //Configurar a requisição no contexto
        RestContext.request  = request;
        RestContext.response = response;

        test.startTest();
            APIOpcoesCondicaoPagamento.RespostaWrapper resposta = APIOpcoesCondicaoPagamento.criarOpcoes();
        test.stopTest();

        //Avaliar o retorno da API
        System.assert(!resposta.success, 'Opção vazia -> Retornou sucesso indevidamente.');
        System.assertEquals('OPCAO_INVALIDA', resposta.errors[0].errorCode, 'Opção vazia -> Código de erro retornado inválido.');
    }

    @isTest
    static void testeOpcaoDuplicada(){

        //Setar o mock a ser usado nas chamadas de API internas
        Test.setMock(HttpCalloutMock.class, new APICondPagamentoMock());

        List<APIOpcoesCondicaoPagamento.RequisicaoWrapper> novasOpcoes = montarRequisicao(2);

        //Colocar o valor duplicado -> o contador do loop gerador de opções começa em zero
        novasOpcoes[1].valor  = 'CLASSE TESTE 0';
        novasOpcoes[1].rotulo = 'CLASSE TESTE 0';

        //Montar a requisição a ser feita à API
        RestRequest request   = new RestRequest();
        RestResponse response = new RestResponse();
        request.requestUri    = URL.getSalesforceBaseUrl().toExternalForm() + '/services/apexrest/gerenciarOpcoesCondicaoPagamento';
        request.httpMethod    = 'POST';
        request.requestBody   = Blob.valueOf(JSON.serialize(novasOpcoes));

        //Configurar a requisição no contexto
        RestContext.request  = request;
        RestContext.response = response;

        test.startTest();
            APIOpcoesCondicaoPagamento.RespostaWrapper resposta = APIOpcoesCondicaoPagamento.criarOpcoes();
        test.stopTest();

        //Avaliar o retorno da API
        System.assert(!resposta.success, 'Opção duplicada -> Retornou sucesso indevidamente.');
        System.assertEquals('OPCAO_DUPLICADA', resposta.errors[0].errorCode, 'Opção duplicada -> Código de erro retornado inválido.');
    }

    @isTest
    static void testeExcederLimiteOpcoes(){

        //Setar o mock a ser usado nas chamadas de API internas
        Test.setMock(HttpCalloutMock.class, new APICondPagamentoMock());

        //O limite é de 1000 opções numa picklist
        List<APIOpcoesCondicaoPagamento.RequisicaoWrapper> novasOpcoes = montarRequisicao(1001);

        //Montar a requisição a ser feita à API
        RestRequest request   = new RestRequest();
        RestResponse response = new RestResponse();
        request.requestUri    = URL.getSalesforceBaseUrl().toExternalForm() + '/services/apexrest/gerenciarOpcoesCondicaoPagamento';
        request.httpMethod    = 'POST';
        request.requestBody   = Blob.valueOf(JSON.serialize(novasOpcoes));

        //Configurar a requisição no contexto
        RestContext.request  = request;
        RestContext.response = response;

        test.startTest();
            APIOpcoesCondicaoPagamento.RespostaWrapper resposta = APIOpcoesCondicaoPagamento.criarOpcoes();
        test.stopTest();

        //Avaliar o retorno da API
        System.assert(!resposta.success, 'Exceder limite -> Retornou sucesso indevidamente.');
        System.assertEquals('LIMITE_OPCOES_ATINGIDO', resposta.errors[0].errorCode, 'Exceder limite -> Código de erro retornado inválido.');
    }

    // //Monta a requisição a ser feita no método da API
    private static List<APIOpcoesCondicaoPagamento.RequisicaoWrapper> montarRequisicao(Integer quantidade){

        List<APIOpcoesCondicaoPagamento.RequisicaoWrapper> requisicao = new List<APIOpcoesCondicaoPagamento.RequisicaoWrapper>();
        Integer i = 0;

        while(i < quantidade){

            APIOpcoesCondicaoPagamento.RequisicaoWrapper opcao = new APIOpcoesCondicaoPagamento.RequisicaoWrapper();
            opcao.valor  = 'CLASSE TESTE ' + i;
            opcao.rotulo = 'CLASSE TESTE ' + i;
            requisicao.add(opcao);

            i++;
        }

        return requisicao;
    }

    //Classe Mock - faz mock de todas as chamadas de API internas para a Tooling API
    public class APICondPagamentoMock implements HttpCalloutMock{

        final String ID_CAMPO              = APIOpcoesCondicaoPagamento.buscarIdCampo();
        final String CUSTOM_FIELD_ENDPOINT = URL.getSalesforceBaseUrl().toExternalForm() + '/services/data/v54.0/tooling/sobjects/CustomField/' + ID_CAMPO;
        final String RECTYPE_ENDPOINT      = URL.getSalesforceBaseUrl().toExternalForm() + '/services/data/v54.0/tooling/sobjects/RecordType/';
        final Id MINI_RECTYPE_ID           = Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName().get('ContratoMini').getRecordTypeId();
        final Id MICRO_RECTYPE_ID          = Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName().get('ContratoMicro').getRecordTypeId();
        final Id OUTRAS_RECTYPE_ID         = Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName().get('OutrasOportunidades').getRecordTypeId();

        public HTTPResponse respond(HTTPRequest requisicao){

            final List<APIOpcoesCondicaoPagamento.ValueCustomField> OPCOES_EXISTENTES = APIOpcoesCondicaoPagamento.buscarOpcoesExistentes();

            //Responder à requisição de Custom Field
            if(requisicao.getEndpoint() == CUSTOM_FIELD_ENDPOINT){
                return interpretarReqCustomField(requisicao, OPCOES_EXISTENTES.size());
            }

            //Leitura dos metadados de tipo de registro
            //Responder à requisição de leitura do tipo de registro - Mini
            else if(requisicao.getEndpoint() == RECTYPE_ENDPOINT + MINI_RECTYPE_ID && requisicao.getMethod() == 'GET'){
                return interpretarReqGETTipoReg('Mini', OPCOES_EXISTENTES, montarRequisicao(2));
            }

            //Responder à requisição de leitura do tipo de registro - Micro
            else if(requisicao.getEndpoint() == RECTYPE_ENDPOINT + MICRO_RECTYPE_ID && requisicao.getMethod() == 'GET'){
                return interpretarReqGETTipoReg('Micro', OPCOES_EXISTENTES, montarRequisicao(2));
            }

            //Responder à requisição de leitura do tipo de registro - Outras
            else if(requisicao.getEndpoint() == RECTYPE_ENDPOINT + OUTRAS_RECTYPE_ID && requisicao.getMethod() == 'GET'){
                return interpretarReqGETTipoReg('Outras', OPCOES_EXISTENTES, montarRequisicao(2));
            }
            
            //Atualizações de tipo de registro
            //Responder à requisição de atualização do tipo de registro - todos os tipos
            else if(
                (requisicao.getEndpoint() == RECTYPE_ENDPOINT + MINI_RECTYPE_ID && requisicao.getMethod() == 'PATCH') ||
                (requisicao.getEndpoint() == RECTYPE_ENDPOINT + MICRO_RECTYPE_ID && requisicao.getMethod() == 'PATCH') ||
                (requisicao.getEndpoint() == RECTYPE_ENDPOINT + OUTRAS_RECTYPE_ID && requisicao.getMethod() == 'PATCH')
            ){
                return interpretarReqPATCHTipoReg(requisicao, OPCOES_EXISTENTES.size());
            }

            return null;
        }

        //Método genérico para montar a instância de HTTPResponse que será retornada à classe da API
        private HTTPResponse montarResposta(String body, Integer statusCode){

            HTTPResponse resposta = new HTTPResponse();
            resposta.setStatusCode(statusCode);
            
            if(body != null){
                resposta.setBody(body);
                resposta.setHeader('Content-Type', 'application/json');
            }
            
            return resposta;
        }

        //Monta a resposta da chamada interna à Tooling API Custom Field - atualizar o metadado
        private HTTPResponse interpretarReqCustomField(HTTPRequest requisicao, Integer qtdExistentes){

            APIOpcoesCondicaoPagamento.MetadadosReqCustomField requisicaoWrapper = 
                                (APIOpcoesCondicaoPagamento.MetadadosReqCustomField) JSON.deserialize(requisicao.getBody(), APIOpcoesCondicaoPagamento.MetadadosReqCustomField.class);
            
            //Verificar se a requisição foi feita corretamente
            System.assertEquals('Opportunity.CondicaoPagamento2__c', requisicaoWrapper.fullName, 'Fullname em CustomField está errado');
            System.assertEquals('Condições de pagamento', requisicaoWrapper.metadata.label, 'Rótulo do campo está errado');
            System.assertEquals('Picklist', requisicaoWrapper.metadata.type, 'Tipo do campo está errado');

            //Dois novos valores estão sendo adicionados; logo, o total de opções enviadas pela API deve ser de existentes + 2
            //"value" é na verdade uma lista de valores
            System.assertEquals(qtdExistentes + 2, requisicaoWrapper.Metadata.valueSet.valueSetDefinition.value.size(), 'Q quantidade de opções no campo está errada');
            
            //A resposta não tem conteúdo e o seu status code é HTTP204
            return montarResposta(null, 204);
        }

        //Monta o JSON a ser retornado pelas chamadas internas de leitura dos metadados de tipo de registro
        //Os três devem ter os mesmos valores de picklist disponíveis e, portanto, não há diferenciação
        private HTTPResponse interpretarReqGETTipoReg(
            String tipo, 
            List<APIOpcoesCondicaoPagamento.ValueCustomField> opcoesExistentes,
            List<APIOpcoesCondicaoPagamento.RequisicaoWrapper> novasOpcoes
        ){

            APIOpcoesCondicaoPagamento.MetadadosReqRecType respostaWrapper = new APIOpcoesCondicaoPagamento.MetadadosReqRecType();
            String label;

            if(tipo == 'Mini'){
                label = 'Contrato Mini';
            }
            else if(tipo == 'Micro'){
                label = 'Contrato Micro';
            }
            else if(tipo == 'Outras'){
                label = 'Outras Oportunidades';
            }

            respostaWrapper.Metadata                         = new APIOpcoesCondicaoPagamento.MetadataRecordType();
            respostaWrapper.Metadata.active                  = true;
            respostaWrapper.Metadata.businessProcess         = 'Oportunidades';
            respostaWrapper.Metadata.compactLayoutAssignment = 'New_Awesome_Companct_Layout';
            respostaWrapper.Metadata.label                   = label;

            APIOpcoesCondicaoPagamento.PicklistValuesRecordType condPagamentoOpt = new APIOpcoesCondicaoPagamento.PicklistValuesRecordType();
            condPagamentoOpt.picklist               = 'CondicaoPagamento2__c';
            condPagamentoOpt.values                 = new List<APIOpcoesCondicaoPagamento.ValuesRecordType>();
            respostaWrapper.Metadata.picklistValues = new List<APIOpcoesCondicaoPagamento.PicklistValuesRecordType>();

            //Adicionar os valores existentes ao JSON a ser retornado
            for(APIOpcoesCondicaoPagamento.ValueCustomField valor : opcoesExistentes){

                APIOpcoesCondicaoPagamento.ValuesRecordType opcaoTipoReg = new APIOpcoesCondicaoPagamento.ValuesRecordType();
                opcaoTipoReg.default_Z = false;
                opcaoTipoReg.valueName = valor.valueName;

                condPagamentoOpt.values.add(opcaoTipoReg);
            }

            //Adicionar os valores novos ao JSON a ser retornado
            for(APIOpcoesCondicaoPagamento.RequisicaoWrapper valor : novasOpcoes){

                APIOpcoesCondicaoPagamento.ValuesRecordType opcaoTipoReg = new APIOpcoesCondicaoPagamento.ValuesRecordType();
                opcaoTipoReg.default_Z = false;
                opcaoTipoReg.valueName = valor.rotulo;

                condPagamentoOpt.values.add(opcaoTipoReg);
            }

            //Atribuir a lista completa ao parâmetro picklistValues
            respostaWrapper.Metadata.picklistValues.add(condPagamentoOpt);

            return montarResposta(JSON.serialize(respostaWrapper), 200);
        }

        //Processa a chamada de API interna para atualizar os tipos de registro
        //Os três tipos de registro usam este método, não há diferenciação
        private HTTPResponse interpretarReqPATCHTipoReg(HTTPRequest requisicao, Integer qtdExistentes){

            APIOpcoesCondicaoPagamento.MetadadosReqRecType mtdTipoReg = (APIOpcoesCondicaoPagamento.MetadadosReqRecType) 
                                                                            JSON.deserialize(requisicao.getBody(), APIOpcoesCondicaoPagamento.MetadadosReqRecType.class);
            Boolean possuiValorCorreto = false;
            Integer indice             = 0;

            //mtdTipoReg.Metadata.picklistValues contém todas as listas de opção do tipo de registro; garantir que uma delas seja
            //o campo CondicaoPagamento2__c
            //Descobrir a posição do campo na lista também, e armazenar no índice
            while(indice < mtdTipoReg.Metadata.picklistValues.size()){

                if(mtdTipoReg.Metadata.picklistValues[indice].picklist == 'CondicaoPagamento2__c'){
                    possuiValorCorreto = true;
                    break;
                }

                indice++;
            }

            //Dois novos valores estão sendo adicionados; logo, o total de opções enviadas pela API deve ser de existentes + 2
            System.assert(possuiValorCorreto, 'O campo CondicaoPagamento2__c não foi encontrado na chamada de atualização do tipo de registro.');
            System.assertEquals(qtdExistentes + 2, mtdTipoReg.Metadata.picklistValues[indice].values.size(), 
                                                            'A quantidade de opções na chamada de atualização do tipo de registro está errada.');

            return montarResposta(null, 204);
        }
    }
}