/**
 * @description       : 
 * @author            : Daniel Belini
 * @group             : 
 * @last modified on  : 02-05-2026
 * @last modified by  : Daniel Belini
**/
public with sharing class IntegracaoVOPlano {

    @future(callout=true)
    public static void sendPlano(Set<Id> triggerIds) {
        List<Opportunity> oportunidades = [ 
        	SELECT Id, Name, AccountId, Numeroproposta__c, Account.IdVirtualOffice2__c, Account.Name, Account.Email__c, Account.DataNascimento__c, Account.SeCPFouCNPJ__c, Account.ShippingStreet, Account.NumeroRuaEntrega__c, Account.ShippingPostalCode, Account.ComplementoEntrega__c, Account.Consultor__r.Login_no_virtual__c, Account.Consultor__r.IdVirtualOffice2__c,PotenciaPicoSistema__c, SubTipo__c, TipoKitPromocional__c, RecordType.DeveloperName, RecordType.Name, paymentMethod__c, StageName, ValorTotalProposta__c, Rede__c, Kwh__c, ConsultorOportunidade__r.Login_no_virtual__c, ConsultorOportunidade__r.IdVirtualOffice2__c, ParceiroRegistroOportunidade__c,Parceiro__r.Name
            FROM Opportunity 
            WHERE Id IN :triggerIds 
        ];

        Set<Id> accountsWithoutVOId = new Set<Id>();
        for (Opportunity opp : oportunidades) {
            if (opp.AccountId != null && (opp.Account == null || String.isBlank(opp.Account.IdVirtualOffice2__c))) {
                accountsWithoutVOId.add(opp.AccountId);
            }
        }

        Map<Id, Account> accountIdToAccount = new Map<Id, Account>();

        if(!accountsWithoutVOId.isEmpty()){
            List<Account> accountsToReprocess = [
                SELECT  Id, IdVirtualOffice2__c, Name, Email__c, DataNascimento__c, SeCPFouCNPJ__c, Consultor__r.Login_no_virtual__c, Consultor__r.IdVirtualOffice2__c, ShippingStreet, NumeroRuaEntrega__c, ShippingPostalCode, ComplementoEntrega__c
                FROM    Account
                WHERE   Id IN :accountsWithoutVOId
            ];

            IntegracaoVOClientePreCadastro.processAccounts(accountsToReprocess, 'sendClienteFromPlano');

            for(Account acc : accountsToReprocess){
                accountIdToAccount.put(acc.Id, acc);
            }
        }

        for(Opportunity opp : oportunidades){
            if(opp.AccountId != null && !accountIdToAccount.containsKey(opp.AccountId) && opp.Account != null){
                accountIdToAccount.put(opp.AccountId, opp.Account);
            }
        }

        for (Opportunity opp : oportunidades) {

        	if (!plano.containsKey(opp.RecordType.DeveloperName)) {
            	continue;
            }
            
            String plano = plano.get(opp.RecordType.DeveloperName);
            Account relatedAccount = opp.AccountId != null ? accountIdToAccount.get(opp.AccountId) : null;

            if (relatedAccount == null || String.isBlank(relatedAccount.IdVirtualOffice2__c)) {
                Utils.createLog('IntegracaoVOPlano', 'skipSendPlanoMissingVOId ' + opp.Id, 'Conta sem IdVirtualOffice2__c. Fluxo não prosseguiu para envio do plano.');
                continue;
            }
            
            PlanoRequest corpoRequisicao = new PlanoRequest();
            corpoRequisicao.IdOportunidade	= opp.Numeroproposta__c;
            corpoRequisicao.idusuario		= Integer.valueOf(relatedAccount.IdVirtualOffice2__c);
            corpoRequisicao.nomeCliente 	= relatedAccount.Name;
        	corpoRequisicao.idplano			= planoId.get(plano);
        	corpoRequisicao.parceiro		= parceiro(opp.Parceiro__r != null ? opp.Parceiro__r.Name : null); //parceiro(opp);
            corpoRequisicao.etapaSalesForce = opp.StageName;
        	corpoRequisicao.tipopagamento	= formPag.get(opp.paymentMethod__c);
            corpoRequisicao.kw				= opp.PotenciaPicoSistema__c;
            corpoRequisicao.tipodoKitPromocional = getPicklistLabel(Opportunity.TipoKitPromocional__c, opp.TipoKitPromocional__c);
            
            if (plano == 'Ezee Livre'){
        		corpoRequisicao.valor		= opp.Rede__c;
            } else {
                corpoRequisicao.valor		= opp.ValorTotalProposta__c;
            }
            
            if (plano == 'Direct'){
                if(opp.SubTipo__c != null){
                    corpoRequisicao.tipoContrato = opp.SubTipo__c;
                }else{
                    corpoRequisicao.tipoContrato = opp.RecordType.Name;
                }
            }
            
            if (opp.ConsultorOportunidade__r != null && opp.ConsultorOportunidade__r.IdVirtualOffice2__c != null) {
    			corpoRequisicao.idConsultorMMN = Integer.valueOf(opp.ConsultorOportunidade__r.IdVirtualOffice2__c);
			}

            try {
                HttpResponse response = chamadaIntegracao(JSON.serialize(corpoRequisicao), 'PlanoVO');
                System.debug('Plano VO Response Status: ' + response.getStatusCode() + ' ' + response.getStatus());
                System.debug('Plano VO Response Body: ' + response.getBody());
                Log__c logRecord = Utils.createLogNoInsert(
                    'IntegracaoVOPlano',
                    'sendPlano ' + opp.Id,
                    response
                );

                if (response.getBody() != null && response.getBody() != '') {
                    Map<String, Object> responseBody = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
                    Boolean error = Boolean.valueOf(responseBody.get('erro'));
                    if (error) {
                        String errorMessage = VOIntegrationEmailAlert.extractErrorMessage(
                            responseBody,
                            response.getBody()
                        );
                        VOIntegrationEmailAlert.sendError(
                            'Plano VO',
                            opp.Name,
                            opp.Id,
                            errorMessage
                        );
                        logRecord.Erro_Enviado__c = true;
                    }
                }

                insert logRecord;
            } catch (Exception e) {
                Log__c logRecord = Utils.createLogNoInsert(
                    'IntegracaoVOPlano',
                    'sendPlano ' + opp.Id,
                    e
                );
                VOIntegrationEmailAlert.sendError(
                    'Plano VO',
                    opp.Name,
                    opp.Id,
                    e.getMessage()
                );
                logRecord.Erro_Enviado__c = true;
                insert logRecord;
            }
        }
    }
            
    private static HttpResponse chamadaIntegracao(String body, String endpointName) {
        Integrador__mdt parametrosIntegracao = [
            SELECT  Id, URL__c
            FROM    Integrador__mdt 
            WHERE   DeveloperName = :endpointName
            LIMIT 1
        ];
        
        if (parametrosIntegracao == null) {
            throw new IllegalArgumentException('Endpoint não encontrado para: ' + endpointName);
        }

        Http httpObj = new Http();
        HttpRequest request = new HttpRequest();
        
        request.setEndpoint(parametrosIntegracao.URL__c);
        request.setMethod('POST');
        request.setHeader('Content-Type', 'application/json');
        request.setBody(body);
        
        return Utils.callIntegrationVO(request);
    }
    
    public class PlanoRequest {
        public String IdOportunidade;
        public Integer idusuario;
        public String nomeCliente;
        public Integer idConsultorMMN;
        public Integer idplano;
        public String parceiro;
        public String etapaSalesForce;
        public String tipoContrato;
        public Integer tipopagamento;
        public Decimal valor;
        public Decimal kw;
        public String tipodoKitPromocional;
    }

    private static final Map<String, String> plano = new Map<String, String>{
        'Solar' 	    => 'Direct',
        'Produtos'      => 'Transition',
        'Servicos'      => 'Transition',
        'Servicos'      => 'Transition',
        'EzeeSolarA'    => 'Ezee Solar',
        'EzeeSolarB'    => 'Ezee Solar',
        'EzeeLivre'     => 'Ezee Livre',
        'EzeeConnect'   => 'Ezee Coonect'
    };

    private static final Map<String, Integer> planoId = new Map<String, Integer>{
        'Transition'    => 1,
        'Ezee Solar'    => 3,
        'Integrador'    => 4,
        'Ezee Coonect'  => 5,
        'Ezee Livre'    => 7,
        'Direct'        => 84,
        'BusinessPlus'  => 99
    };
    
    //Customização até definição dos parceiros de todos os produtos na oportunidade ser no campo ParceiroRegistroOportunidade__c
    private static String parceiro(String parceiro) {
    
    	if(parceiro == 'Enerzee - Grupo A' || parceiro == 'Enerzee - Grupo B'){
            return 'Enerzee';
        } else {
            return parceiro;
        }
    
	}

	private static final Map<String, Integer> formPag = new Map<String, Integer>{
		'PayPal' 						 => 1,
		'SALDO + E-CASH' 				 => 2,
		'Boleto' 						 => 3,
		'Transferência Bancária' 		 => 6,
		'PIX' 							 => 10,
		'Cartão Crédito' 				 => 11,
		'Financiamento Bancário' 		 => 12,
		'E-cash' 						 => 13,
		'Aguardando Pagamento' 			 => 14,
		'Parcial E-cash e Saldo Virtual' => 15,
		'Manual' 						 => 16,
		'Pix e Saldo' 					 => 17
	};

    private static String getPicklistLabel(SObjectField field, String value) {
        if (String.isBlank(value)) {
            return null;
        }

		for (Schema.PicklistEntry option : field.getDescribe().getPicklistValues()) {
			if (option.getValue() == value) {
				return option.getLabel();
			}
		}
		return value;
	}
}