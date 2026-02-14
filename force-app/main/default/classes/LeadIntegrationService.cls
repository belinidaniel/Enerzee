/**
 * @description       : 
 * @author            : Daniel Belini
 * @group             : 
 * @last modified on  : 10-09-2025
 * @last modified by  : Daniel Belini
**/
public with sharing class LeadIntegrationService {
    // Classe de entrada para o Flow
    public class LeadInput {
        @InvocableVariable(required=true)
        public String leadId;
    }
    
    // Classe de saída para o Flow
    public class LeadOutput {
        @InvocableVariable
        public Integer statusCode;
        @InvocableVariable
        public String responseBody;
        @InvocableVariable
        public String errorMessage;
    }
    
    // Método chamado pelo Flow
    @InvocableMethod(label='Enviar Lead para App Externo' description='Envia os dados do Lead para a API externa')
    public static List<LeadOutput> sendLeadsToExternalApp(List<LeadInput> inputs) {
        List<LeadOutput> results = new List<LeadOutput>();
        
        system.debug('@@@@');
        
        for (LeadInput input : inputs) {
            LeadOutput result = new LeadOutput();
            
            integrateLead(input.leadId);
            
            results.add(result);
        }
        
        return results;
    }

    @future(callout=true)
    public static void integrateLeadAsync(Set<Id> leadIds) {
        if (leadIds == null || leadIds.isEmpty()) {
            return;
        }

        for (Id leadId : leadIds) {
            if (leadId == null) {
                continue;
            }
            integrateLead(String.valueOf(leadId));
        }
    }
    
    public static void integrateLead(String leadId) {
		Lead leadRecord = [
            SELECT
            Id, 
            Name,
            FirstName,
            LastName,
            Email, 
            CPFCNPJ__c, 
            CustoEnergiaMes__c, 
            Status, 
            ConsultorRegional__r.IdVirtualOffice__c, 
            MobilePhone, 
            Lb065_FaturaEnergia__c, 
            Lb065_ProdutoInteresse__c, 
            Lb065_HistoricoLead__c, 
            Lb065_Estado__c,
            LeadSource,
            Title,
            Company,
            Street,
            City,
            Country,
            State,
            InteresseEnergiaRenovavel__c,
            InteresseEnergiaSolar__c,
            TipoDeImovel__c,
            ValorContaEnergia__c,
            Rating,
			Mensagem__c,
			Complemento__c,
            ReasonNotConverted__c,
            OtherReason__c,
            PostalCode
            FROM Lead
            WHERE Id = :leadId
            LIMIT 1
        ];

        try {
            // Buscar o endpoint do Custom Metadata
            String endpoint = getEndpointFromMetadata('LeadIntegration');

			String leadStateCustom = leadRecord.State != null ? leadRecord.State : LeadIntegrationService.getPicklistLabel(Lead.Lb065_Estado__c, leadRecord.Lb065_Estado__c);
			String leadSourceSf = getPicklistLabel(Lead.LeadSource, leadRecord.LeadSource);
            String leadInterestOES = getPicklistLabel(Lead.InteresseEnergiaRenovavel__c, leadRecord.InteresseEnergiaRenovavel__c);
            String leadInterestedSEF = getPicklistLabel(Lead.InteresseEnergiaSolar__c, leadRecord.InteresseEnergiaSolar__c);
			String leadPropertyType = getPicklistLabel(Lead.TipoDeImovel__c, leadRecord.TipoDeImovel__c);
            String leadCustoEnergiaMes = getPicklistLabel(Lead.CustoEnergiaMes__c, leadRecord.CustoEnergiaMes__c);
            String leadValorContaEnergia = getPicklistLabel(Lead.ValorContaEnergia__c, leadRecord.ValorContaEnergia__c);
            String leadRating = getPicklistLabel(Lead.Rating, leadRecord.Rating);

			Integer leadSourceValue;
			Integer leadInterestOESValue;
			Integer leadInterestedSEFValue;
			Integer leadPropertyTypeValue;
			Integer leadCustoEnergiaMesValue;
			Integer leadValorContaEnergiaValue;
			Integer leadRatingValue;

            switch on leadSourceSf {
                when 'Nivello' {
                    leadSourceValue = 1;
                }
                when 'Anúncio' {
                    leadSourceValue = 2;
                }
                when 'Indicação de funcionário' {
                    leadSourceValue = 4;
                }
                when 'Google AdWords' {
                    leadSourceValue = 5;
                }
                when 'Parceiro' {
                    leadSourceValue = 6;
                }
                when 'Purchased List' {
                    leadSourceValue = 7;
                }
                when 'Feira ou convenção' {
                    leadSourceValue = 8;
                }
                when 'Webinar' {
                    leadSourceValue = 9;
                }
                when 'Website' {
                    leadSourceValue = 10;
                }
                when 'Facebook Super Black - Consumidor Final' {
                    leadSourceValue = 13;
                }
                when 'Quero Ser Enerzee' {
                    leadSourceValue = 14;
                }
                when 'Super Black - Consumidor Final' {
                    leadSourceValue = 15;
                }
                when 'Outro' {
                    leadSourceValue = 16;
                }
                when else {
                    leadSourceValue = null; // Valor default se não for nenhum dos casos
                }
        	}
            
            switch on leadInterestOES {
                when 'Armazenamento de energia (baterias)' {
                    leadInterestOESValue = 1;
                }
                when 'Carregadores para carros elétricos' {
                    leadInterestOESValue = 2;
                }
                when 'Automação residencial (casa inteligente)' {
                    leadInterestOESValue = 3;
                }
                when 'Todas as opções' {
                    leadInterestOESValue = 4;
                }
                when 'Por enquanto, não!' {
                    leadInterestOESValue = 5;
                }
                when else {
                    leadInterestOESValue = null; // Valor default caso não caia em nenhum dos casos
                }
            }

			switch on leadInterestedSEF {
                when 'Minha casa' {
                    leadInterestedSEFValue = 1;
                }
                when 'Minha empresa' {
                    leadInterestedSEFValue = 2;
                }
                when 'Para os dois' {
                    leadInterestedSEFValue = 3;
                }
                when else {
                    leadInterestedSEFValue = null; // Valor default caso não corresponda a nenhum
                }
            }

			switch on leadPropertyType {
                when 'Com telhado cerâmico' {
                    leadPropertyTypeValue = 1;
                }
                when 'Com telhado fibrocimento' {
                    leadPropertyTypeValue = 2;
                }
                when 'Com telhado metálico' {
                    leadPropertyTypeValue = 3;
                }
                when 'Com laje' {
                    leadPropertyTypeValue = 4;
                }
                when 'Edifício' {
                    leadPropertyTypeValue = 5;
                }
                when else {
                    leadPropertyTypeValue = null; // Valor padrão se não bater nenhum
                }
            }

            switch on leadCustoEnergiaMes {
                when 'Até R$ 300' {
                    leadCustoEnergiaMesValue = 1;
                }
                when 'Até R$ 300 a R$ 500' {
                    leadCustoEnergiaMesValue = 2;
                }
                when 'De R$ 500 a R$ 1.000' {
                    leadCustoEnergiaMesValue = 3;
                }
                when 'mais de R$ 1.000' {
                    leadCustoEnergiaMesValue = 4;
                }
                when else {
                    leadCustoEnergiaMesValue = null; // Valor padrão caso não caia em nenhum
                }
            }
            
            switch on leadValorContaEnergia {
                when 'Até R$ 200' {
                    leadValorContaEnergiaValue = 1;
                }
                when 'Entre R$ 200 e R$ 499' {
                    leadValorContaEnergiaValue = 2;
                }
                when 'Acima de R$ 500' {
                    leadValorContaEnergiaValue = 3;
                }
                when else {
                    leadValorContaEnergiaValue = null; // Valor default se não corresponder
                }
            }

            switch on leadRating {
                when 'Muito importante' {
                    leadRatingValue = 1;
                }
                when 'Importante' {
                    leadRatingValue = 2;
                }
                when 'Pouco importante' {
                    leadRatingValue = 3;
                }
                when 'Prioritário' {
                    leadRatingValue = 4;
                }
                when 'Sem classificação' {
                    leadRatingValue = 5;
                }
            }
            
            // Montar JSON
            Map<String, Object> payload = new Map<String, Object>{
                'firstName'=> leadRecord.FirstName,
                'lastName'=> leadRecord.LastName,
                'email'=> leadRecord.Email,
                'document'=> leadRecord.CPFCNPJ__c,
                'invoiceAmount'=> leadRecord.Lb065_FaturaEnergia__c,
                'phone'=> leadRecord.MobilePhone,
                'product'=> leadRecord.Lb065_ProdutoInteresse__c,
                'status'=> 1,
                'idSalesForce'=> leadRecord.Id,
                'consultantId'=> leadRecord.ConsultorRegional__r.IdVirtualOffice__c,
                'conversationHistory'=> leadRecord.Lb065_HistoricoLead__c,
                'company'=> leadRecord.Company,
                'title'=> leadRecord.Title,
                'message'=> leadRecord.Mensagem__c,
                'street'=> leadRecord.Street,
                'city'=> leadRecord.City,
                'state'=> leadStateCustom,
                'country'=> leadRecord.Country,
                'complement'=> leadRecord.Complemento__c,
                'postalCode'=> leadRecord.PostalCode,
                'leadSource'=> leadSourceValue,
                'interestOtherEnergySolutions'=> leadInterestOESValue,
                'interestedSolarEnergyFor'=> leadInterestedSEFValue,
                'propertyType'=> leadPropertyTypeValue,
               	'IdEnergyCostMonth'=> leadCustoEnergiaMesValue,
                'IdEnergyBill'=> leadValorContaEnergiaValue,
                'IdRatting'=> leadRatingValue
            	};
                        
            String jsonPayload = JSON.serialize(payload);
            
            System.debug('Payload JSON enviado: ' + jsonPayload);
            
            HttpRequest req = new HttpRequest();
            req.setEndpoint(endpoint);
            req.setMethod('PATCH'); 
            req.setHeader('Content-Type', 'application/json');
            req.setBody(jsonPayload);
            
            HttpResponse res = Utils.callIntegrationNivello(req);
            
            //result.statusCode = res.getStatusCode();
            //result.responseBody = res.getBody();
            
            // Handle the response
            if (res.getStatusCode() == 200) {
                System.debug('Request successful, ' + res.getBody());
                createLog('IntegracaoDistribuicaoLead', 'sendUrlSimulation ' + leadRecord.Id, res, leadRecord.Id);

                Map<String, Object> bodyMap = (Map<String, Object>)JSON.deserializeUntyped(res.getBody());
                Map<String, Object> dataMap = (Map<String, Object>)bodyMap.get('data');
                String externalId = (String)dataMap.get('id');

				// Atualiza o campo de integração no Lead
                leadRecord.Lab065_IntegracaoDistribuicaoLead__c = true;
                leadRecord.ExternalId__c = externalId;
                update leadRecord;
            } else {
                Utils.createLog('IntegracaoDistribuicaoLead', 'sendUrlSimulation failed ' + leadRecord.Id, res);
                System.debug('Request failed: ' + res.getStatus());
            }
            
        } catch (Exception e) {
            createLog('IntegracaoDistribuicaoLead', 'Exception in sendUrlSimulation ' + leadRecord.Id, e.getMessage(), leadRecord.Id);
        }
        
    }
    
    // Método auxiliar para pegar o endpoint do Custom Metadata
    private static String getEndpointFromMetadata(String name) {
        List<Integrador__mdt> registros = [
            SELECT URL__c
            FROM Integrador__mdt
            WHERE DeveloperName = :name
            LIMIT 1
        ];
        
        if (!registros.isEmpty()) {
            return registros[0].URL__c;
        }
        return null;
    }
    
    private static String getPicklistLabel(SObjectField field, String value) {
		for (Schema.PicklistEntry option : field.getDescribe().getPicklistValues()) {
			if (option.getValue() == value) {
				return option.getLabel();
			}
		}
		return value;
	}

	public static Log__c createLogNoInsert(String className, String methodName, Object source, String LeadId){

        Log__c lg = new Log__c(
            Class__c  = className,
            Method__c = methodName,
            Lab065_LeadRelated__c = LeadId
        );

        //Set additional log fields based on source type
        //General exceptions
        if(source instanceOf Exception){

            //Exception e = (Exception) source;

            //lg.Message__c          = e.getMessage();
            //lg.Type__c             = e.getTypeName();
            //lg.LineNumber__c       = String.valueOf(e.getLineNumber());
            //lg.StackTraceString__c = e.getStackTraceString();
        }

        //Callouts
        else if(source instanceOf HttpResponse){

            HttpResponse resp = (HttpResponse) source;

            lg.StatusCode__c   = resp.getStatusCode();
            lg.ResponseBody__c = resp.getBody().length() > 131072 ? resp.getBody().substring(0, 131072) : resp.getBody();
            lg.Status__c = resp.getStatus();
        }

        return lg;
    }

    public static void createLog(String className, String methodName, Object source, String LeadId){
        insert createLogNoInsert(className, methodName, source, LeadId);
    }
}
