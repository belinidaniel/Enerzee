/**
 * @description       : 
 * @author            : Daniel Belini
 * @group             : 
 * @last modified on  : 08-20-2025
 * @last modified by  : Daniel Belini
**/
public with sharing class IntegracaoVOPlano {

    @future(callout=true)
    public static void sendPlano(Set<Id> triggerIds) {
        List<Opportunity> oportunidades = [ 
        	SELECT Id, Numeroproposta__c, Account.IdVirtualOffice2__c,PotenciaPicoSistema__c,Account.Name, SubTipo__c, RecordType.DeveloperName, RecordType.Name, paymentMethod__c, StageName, ValorTotalProposta__c, Rede__c, Kwh__c, ConsultorOportunidade__r.Login_no_virtual__c, ConsultorOportunidade__r.IdVirtualOffice2__c, ParceiroRegistroOportunidade__c,Parceiro__r.Name
            FROM Opportunity 
            WHERE Id IN :triggerIds 
        ];

        for (Opportunity opp : oportunidades) {

        	if (!plano.containsKey(opp.RecordType.DeveloperName)) {
            	continue;
            }
            
            String plano = plano.get(opp.RecordType.DeveloperName);
            
            PlanoRequest corpoRequisicao = new PlanoRequest();
            corpoRequisicao.IdOportunidade	= opp.Numeroproposta__c;
            corpoRequisicao.idusuario		= opp.Account.IdVirtualOffice2__c != null ? Integer.valueOf(opp.Account.IdVirtualOffice2__c) : 0;
            corpoRequisicao.nomeCliente 	= opp.Account.Name;
        	corpoRequisicao.idplano			= planoId.get(plano);
        	corpoRequisicao.parceiro		= parceiro(opp.Parceiro__r.Name); //parceiro(opp);
            corpoRequisicao.etapaSalesForce = opp.StageName;
        	corpoRequisicao.tipopagamento	= formPag.get(opp.paymentMethod__c);
            corpoRequisicao.kw				= opp.PotenciaPicoSistema__c;
            
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
                Utils.createLog('IntegracaoVOPlano', 'sendPlano ' + lead.Id, response);

                if (response.getBody() != null && response.getBody() != '') {
                    Map<String, Object> responseBody = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
                    Boolean success = Boolean.valueOf(responseBody.get('erro'));
                }

            } catch (Exception e) {
                Utils.createLog('IntegracaoVOPlano', 'sendPlano ' + lead.Id, e);
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
}