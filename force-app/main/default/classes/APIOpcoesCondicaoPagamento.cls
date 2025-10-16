@RestResource(urlMapping='/gerenciarOpcoesCondicaoPagamento')
global with sharing class APIOpcoesCondicaoPagamento{

    /* 
        Autor: Bruno Peixoto, JFOX
        Data: 30/09/2022
        Objetivo: API para adicionar novas opções de condição de pagamento no campo Opportunity.CondicaoPagamento2__c
        É idempotente e busca o Id do campo
        Etapas:
        1 - Recebe requisição
        2 - Busca opções existentes do campo através do Schema
        3 - Adiciona as novas opções às existentes
        4 - Atualiza as opções do campo via Tooling API
        5 - Consulta Tooling API para pegar o metadado do tipo de registro
        6 - Adiciona as opções novas às existentes no metadado do tipo de registro
        7 - Atualiza o metadado do tipo de registro com todas as opções (novas + existentes)
        5, 6 e 7 ocorrem 3 vezes, uma para cada tipo de registro (Mini, Micro e Outras)
    */
    
    @HttpPost
    global static RespostaWrapper criarOpcoes(){

        final String NOME_TIPOREG_MINI   = 'ContratoMini';
        final String NOME_TIPOREG_MICRO  = 'ContratoMicro';
        final String NOME_TIPOREG_OUTRAS = 'OutrasOportunidades';

        System.RestRequest requisicao = System.RestContext.request;
        RespostaWrapper resposta      = new RespostaWrapper();
        List<RequisicaoWrapper> novasOpcoes;
        
        //Interpretar JSON recebido
        try{
            novasOpcoes = (List<RequisicaoWrapper>) JSON.deserialize(requisicao.requestBody.toString(), List<RequisicaoWrapper>.class);
        }
        catch(Exception e){

            Utils.createLog('APIcondPagamentoOpt', 'criarOpcoes - erro no JSON recebido', requisicao);

            resposta = gerarRespostaErro(
                'JSON_INVALIDO', 
                'Houve um erro ao tentar interpretar o JSON recebido. Assegure-se que a sua estrutura e valores estão corretos.'
            );

            RestContext.response.statusCode = 400;
            return resposta;
        }

        //A Tooling API precisa que todas as opções existentes também sejam enviadas
        List<ValueCustomField> opcoesExistentes = buscarOpcoesExistentes();

        resposta.success = true;
        resposta         = validarRequisicao(resposta, opcoesExistentes.size(), novasOpcoes);

        if(resposta.success){

            List<ValueCustomField> valoresCombinados = montarListaFinalDeValores(opcoesExistentes, novasOpcoes);

            try{
                atualizarCampoComMetadataAPI(valoresCombinados);

                atualizarTiposDeRegistro(new List<String>{
                    'ContratoMini', 'ContratoMicro', 'OutrasOportunidades'
                }, valoresCombinados);

            }
            catch(Exception e){

                Utils.createLog('APIcondPagamentoOpt', 'criarOpcoes - exceção no callout de custom field', e.getMessage());

                resposta = gerarRespostaErro('ERRO_API_INTERNO_SF', 'Houve um erro no processamento interno do Salesforce.');
                RestContext.response.statusCode = 500;
                return resposta;
            }

        //Erro de validação, bad request
        }else{
            RestContext.response.statusCode = 400;
        }

        return resposta;    
    }

    private static void atualizarCampoComMetadataAPI(List<ValueCustomField> valores) {
        
        MetadataService.MetadataPort service = new MetadataService.MetadataPort();
        service.SessionHeader = new MetadataService.SessionHeader_element();
        service.SessionHeader.sessionId = UserInfo.getSessionId();
        //service.endpoint_x = 'https://' + System.Url.getOrgDomainUrl().getHost() + '/services/Soap/m/63.0';

        MetadataService.CustomField campo = new MetadataService.CustomField();
        campo.fullName = 'Opportunity.CondicaoPagamento2__c';
        campo.label = 'Condições de pagamento';
        campo.type_x = 'Picklist';
        campo.description = 'As configurações deste campo são controladas pela API "APIcondPagamentoOpt", usada pelo SAP.' +
                             ' Última atualização: ' + System.now().format();
        campo.required         = false;
        campo.trackFeedHistory = false;
        campo.trackHistory     = false;
        campo.trackTrending    = false;
        

        List<MetadataService.CustomValue> listaValores = new List<MetadataService.CustomValue>();
        for (ValueCustomField opcao : valores) {
            MetadataService.CustomValue val = new MetadataService.CustomValue();
            val.fullName = opcao.valueName;
            val.description = '';
            val.default_x = false;
            val.label = opcao.label;
            val.isActive = true;
            listaValores.add(val);
        }

        MetadataService.ValueSetValuesDefinition valSetValuesDef = new MetadataService.ValueSetValuesDefinition();
        valSetValuesDef.value = listaValores;
        valSetValuesDef.sorted = false;

        MetadataService.ValueSet valSet = new MetadataService.ValueSet();
        valSet.valueSetDefinition = valSetValuesDef;
        valSet.restricted = true;

        campo.valueSet = valSet;

        MetadataService.SaveResult[] resultados = service.updateMetadata(
            new MetadataService.Metadata[] { campo }
        );

        if (!resultados[0].success) {
            throw new AuraHandledException('Erro ao atualizar campo via Metadata API: ' + resultados[0].errors[0].message);
        }
    }

    private static void atualizarTiposDeRegistro(List<String> nomesTipos, List<ValueCustomField> valores) {
        for (String nome : nomesTipos) {
            String recTypeId = Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName().get(nome).getRecordTypeId();
            MetadataService.RecordType recordType = new MetadataService.RecordType();
            recordType.fullName = 'Opportunity.' + nome;

            MetadataService.RecordTypePicklistValue picklistValores = new MetadataService.RecordTypePicklistValue();
            picklistValores.picklist = 'CondicaoPagamento2__c';
            picklistValores.values = new List<MetadataService.PicklistValue>();

            for (ValueCustomField opcao : valores) {
                MetadataService.PicklistValue val = new MetadataService.PicklistValue();
                val.fullName = opcao.valueName;
                val.default_x = false;
                picklistValores.values.add(val);
            }

            recordType.picklistValues = new List<MetadataService.RecordTypePicklistValue>{ picklistValores };

            MetadataService.MetadataPort service = new MetadataService.MetadataPort();
            service.SessionHeader = new MetadataService.SessionHeader_element();
            service.SessionHeader.sessionId = UserInfo.getSessionId();
            service.endpoint_x = 'https://' + System.Url.getOrgDomainUrl().getHost() + '/services/Soap/m/63.0';

            MetadataService.SaveResult[] results = service.updateMetadata(
                new MetadataService.Metadata[] { recordType }
            );

            if (!results[0].success) {
                throw new AuraHandledException('Erro ao atualizar RecordType ' + nome + ': ' + results[0].errors[0].message);
            }
        }
    }

    private static List<ValueCustomField> montarListaFinalDeValores(List<ValueCustomField> existentes, List<RequisicaoWrapper> novas) {
        List<ValueCustomField> valores = new List<ValueCustomField>();
        Set<String> existentesValores = new Set<String>();

        for (ValueCustomField existente : existentes) {
            valores.add(existente);
            existentesValores.add(existente.valueName);
        }

        for (RequisicaoWrapper nova : novas) {
            if (!existentesValores.contains(nova.valor)) {
                ValueCustomField val = new ValueCustomField();
                val.default_Z = false;
                val.label = nova.rotulo;
                val.valueName = nova.valor;
                valores.add(val);
            }
        }
        return valores;
    }

    //Valida os dados enviados pelo requisitante
    private static RespostaWrapper validarRequisicao(RespostaWrapper resposta, Integer qtdOpcoesExistentes, List<RequisicaoWrapper> novasOpcoes){

        //Apenas 1000 opções podem ser adicionadas a uma Picklist
        final Integer LIMITE_CAMPO = 1000;
        Integer qtdNovasOpcoes     = novasOpcoes.size();

        //Verificar se o limite de opções está sendo respeitado
        if(qtdOpcoesExistentes + qtdNovasOpcoes > LIMITE_CAMPO){

            String mensagem = 'O limite de opções (' + LIMITE_CAMPO + ') no campo Condição de pagamento foi atingido. ' + 
                                                            'Quantidade existente: ' + qtdOpcoesExistentes + 
                                                            ', Quantidade sendo adicionada: ' + novasOpcoes.size();

            resposta = gerarRespostaErro('LIMITE_OPCOES_ATINGIDO', mensagem);
            return resposta;
        }

        //Iterar a requisição e garantir que as opções são válidas e não estão duplicadas
        List<String> refOpcoes = new List<String>();
        for(RequisicaoWrapper novaOpcao : novasOpcoes){
            
            //Se há opções vazias
            if(novaOpcao.rotulo == null || novaOpcao.valor == null){
                resposta = gerarRespostaErro('OPCAO_INVALIDA', 'O rótulo ou o valor de uma das opções enviadas está vazio. ' + 
                                                                'Assegure-se que todas as opções possuem um rótulo e um valor.');
            }
            else{
                //Se há opções duplicadas
                if(refOpcoes.contains(novaOpcao.rotulo)){
                    resposta = gerarRespostaErro('OPCAO_DUPLICADA', 'O rótulo ou o valor de uma das opções enviadas está duplicado. ' + 
                                                                    'Assegure-se que todas as opções enviadas são únicas.');
                }
                refOpcoes.add(novaOpcao.rotulo);
            }
        }

        return resposta;
    }

    //Faz chamadas de API para a Tooling API
    private static HTTPResponse chamadaAPIInterna(String body, String metodo, String endpoint){ 

        Http httpObj = new Http();
        HttpRequest request = new HttpRequest();

        request.setEndpoint(endpoint);
        request.setMethod(metodo);
        request.setHeader('Authorization', 'Bearer ' + UserInfo.getSessionID());
        request.setTimeOut(120000);

        if(metodo != 'GET'){
            request.setHeader('Content-Type', 'application/json');
            request.setBody(body);
        }

        return httpobj.send(request);
    }

    //Monta os erros a serem retornados por esta API
    private static RespostaWrapper gerarRespostaErro(String errorCode, String message){

        RespostaWrapper resposta = new RespostaWrapper();
        resposta.success = false;
        resposta.errors  = new List<RespostaErroWrapper>();

        RespostaErroWrapper erro = new RespostaErroWrapper();
        erro.errorCode = errorCode;
        erro.message   = message;
        resposta.errors.add(erro);

        return resposta;
    }

    @TestVisible
    private static List<ValueCustomField> buscarOpcoesExistentes(){

        List<ValueCustomField> opcoesExistentes = new List<ValueCustomField>();

        List<Schema.PicklistEntry> opcoes = Opportunity.CondicaoPagamento2__c.getDescribe().getPicklistValues();

        for(Schema.PicklistEntry opcao : opcoes){

            ValueCustomField val = new ValueCustomField();
            val.default_Z   = false;   //Nome reservado, deve ser substituído no JSON
            val.label       = opcao.getLabel();
            val.valueName   = opcao.getValue();
            opcoesExistentes.add(val);
        }     

        return opcoesExistentes;
    }

    //Busca o Id do campo Opportunity.CondicaoPagamento2__c
    @TestVisible
    private static Id buscarIdCampo(){

        FieldDefinition defCampo = [SELECT 
                                        Id, DurableId 
                                    FROM FieldDefinition 
                                    WHERE 
                                        EntityDefinition.QualifiedApiName = 'Opportunity' 
                                        AND 
                                        DeveloperName = 'CondicaoPagamento2'];

        Id id18caracteres = defCampo.durableId.subStringAfter('Opportunity.');        

        return id18caracteres;
    }

    private static Boolean gerenciarOpcoesTipoRegistro(String nomeTipoReg, MetadadosReqCustomField mtdCustomField){

        final Id RECTYPE_ID   = Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName().get(nomeTipoReg).getRecordTypeId();
        String endpoint       = URL.getSalesforceBaseUrl().toExternalForm() + '/services/data/v63.0/tooling/sobjects/RecordType/';
        HTTPResponse respostaAtualizacao;

        HTTPResponse respostaLeitura = chamadaAPIInterna(null, 'GET', endpoint + RECTYPE_ID);

        //Se a requisição de leitura do metadado deu certo, continuar para atualizar o metadado com novas opções
        if(respostaLeitura.getStatusCode() == 200){
            
            respostaAtualizacao = atualizarMetadadosTipoReg(respostaLeitura, mtdCustomField, endpoint + RECTYPE_ID);

            //A API retorna 204 quando há sucesso
            if(respostaAtualizacao.getStatusCode() == 204){
                return true;
            }
            else{

                Utils.createLog(
                    'APIcondPagamentoOpt', 
                    'gerenciarOpcoesTipoRegistro - adicionar opções ao tipo de registro  ' + nomeTipoReg,
                    respostaAtualizacao
                );
                return false;
            }
        }
        else{
            return false;
        }
    }

    private static HTTPResponse atualizarMetadadosTipoReg(HTTPResponse respostaLeitura, MetadadosReqCustomField mtdCustomField, String endpoint){

        HTTPResponse resposta;
        MetadadosReqRecType mtdTipoReg = (MetadadosReqRecType) JSON.deserialize(respostaLeitura.getBody(), MetadadosReqRecType.class);

        //Atualizar o tipo de regitro Mini
        MetadadosReqRecType metadadoWrapper = montarReqTipoReg(mtdCustomField, mtdTipoReg);

        String body = JSON.serializePretty(metadadoWrapper).replace('"default_Z"', '"default"');

        resposta = chamadaAPIInterna(body, 'PATCH', endpoint);

        return resposta;
    }

    //Monta requisição de atualização de metadado de tipo de registro. Reusável, é usado pelos três
    private static MetadadosReqRecType montarReqTipoReg(MetadadosReqCustomField mtdCustomField, MetadadosReqRecType mtdTipoReg){

        //Opções oriundas da leitura do metadado do tipo de registro
        List<PicklistValuesRecordType> existentesTipoRec = mtdTipoReg.Metadata.picklistValues;

        PicklistValuesRecordType condPagamentoOpt = new PicklistValuesRecordType();
        condPagamentoOpt.picklist                 = 'CondicaoPagamento2__c';
        condPagamentoOpt.values                   = new List<ValuesRecordType>();

        //Ler todas as opções do campo para adicioná-los ao metadado do record type. Não é possível apenas incrementar; 
        //deve-se recriar todas as opções
        for(ValueCustomField val : mtdCustomField.Metadata.valueSet.valueSetDefinition.value){

            ValuesRecordType opcaoTipoReg = new ValuesRecordType();
            opcaoTipoReg.default_Z        = false;
            opcaoTipoReg.valueName        = val.valueName;

            condPagamentoOpt.values.add(opcaoTipoReg);
        }

        //Atribuir a nova lista com os valores atualizados no metadado que foi retornado pela Tooling API
        mtdTipoReg.Metadata.picklistValues.add(condPagamentoOpt);

        return mtdTipoReg;
    }

    //---------------------------------------------------------- Wrappers desta API ------------------------------------------------------------
    @TestVisible
    private class RequisicaoWrapper {
        public String rotulo;
        public String valor;
    }

    @TestVisible
    global class RespostaWrapper {
        public List<RespostaErroWrapper> errors;
        public Boolean success;
    }

    @TestVisible
    private class RespostaErroWrapper {
        public String message;
        public String errorCode;
    }

    //---------------------------------------------- Wrappers da API de metadados - Tooling, CustomField ------------------------------------------
    @TestVisible
    private class MetadadosReqCustomField {
        public MetadataCustomField Metadata;
        public String FullName;
    }
   
    @TestVisible
    private class MetadataCustomField {
        public String businessOwnerGroup;
        public String businessOwnerUser;
        public String businessStatus;
        public String caseSensitive;
        public String complianceGroup;
        public String customDataType;
        public String defaultValue;
        public String deleteConstraint;
        public String deprecated;
        public String description;
        public String displayFormat;
        public String displayLocationInDecimal;
        public String encryptionScheme;
        public String escapeMarkup;
        public String externalDeveloperName;
        public Boolean externalId;
        public String formula;
        public String formulaTreatBlanksAs;
        public String inlineHelpText;
        public String isAIPredictionField;
        public String isConvertLeadDisabled;
        public String isFilteringDisabled;
        public String isNameField;
        public String isSortingDisabled;
        public String label;
        public String length;
        public String lookupFilter;
        public String maskChar;
        public String maskType;
        public String metadataRelationshipControllingField;
        public String populateExistingRows;
        public String precision;
        public String readOnlyProxy;
        public String referenceTargetField;
        public String referenceTo;
        public String relationshipLabel;
        public String relationshipName;
        public String relationshipOrder;
        public String reparentableMasterDetail;
        public Boolean required;
        public String restrictedAdminField;
        public String scale;
        public String securityClassification;
        public String startingNumber;
        public String stripMarkup;
        public String summarizedField;
        public String summaryFilterItems;
        public String summaryForeignKey;
        public String summaryOperation;
        public Boolean trackFeedHistory;
        public Boolean trackHistory;
        public Boolean trackTrending;
        public String translateData;
        public String type;
        public String unique;
        public String urls;
        public ValueSetCustomField valueSet;
        public String visibleLines;
        public String writeRequiresMasterRead;
    }
    
    @TestVisible
    private class ValSetDefCustomField {
        public Boolean sorted;
        public List<ValueCustomField> value;
    }
    
    @TestVisible
    private class ValueSetCustomField {
        public String controllingField;
        public Boolean restricted;
        public ValSetDefCustomField valueSetDefinition;
        public String valueSetName;
        public List<Object> valueSettings;
    }

    @TestVisible
    private class ValueCustomField {
        public String color;
        public Boolean default_Z;   //Nome reservado, deve ser substituído no JSON
        public String description;
        public String isActive;
        public String label;
        public String urls;
        public String valueName;
    }

    //------------------------------------------ Wrappers da API de metadados - Tooling, RecordType ------------------------------------
    @TestVisible
    private class MetadadosReqRecType {
        public MetadataRecordType Metadata;
    }

    @TestVisible
    private class MetadataRecordType {
		public Boolean active;
		public String businessProcess;
		public String compactLayoutAssignment;
		public String description;
		public String label;
		public List<PicklistValuesRecordType> picklistValues;
	}

    @TestVisible
    private class PicklistValuesRecordType {
		public String picklist;
		public List<ValuesRecordType> values;
	}
	
    @TestVisible
	private class ValuesRecordType {
		public Boolean allowEmail;
		public Boolean closed;
		public String color;
		public List<String> controllingFieldValues;
		public Boolean converted;
		public Boolean cssExposed;
		public Boolean default_Z;
		public String description;
		public String forecastCategory;
		public Boolean highPriority;
		public Boolean isActive;
		public Integer probability;
		public String reverseRole;
		public Boolean reviewed;
		public String valueName;
		public Boolean won;
	}
}