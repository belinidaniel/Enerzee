/**
 * @description       : Controller para retentativa síncrona de integração SAP via LWC. Chama execute(null) do Queueable correspondente diretamente,
 *                       retornando o resultado imediatamente ao componente.
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-27-2026
 * @last modified by  : Daniel Belini
 * @test              : SapIntegrationRetryControllerTest
 **/
public with sharing class SapIntegrationRetryController {

	@AuraEnabled
	public static SapRetryResult retryIntegration(Id recordId, String objectApiName) {
		Set<Id> ids = new Set<Id>{ recordId };

		if (objectApiName == 'Account') {
			new IntegracaoSAPCliente(ids).execute(null);
		} else if (objectApiName == 'Opportunity') {
			new IntegracaoSAPContrato(ids).execute(null);
		} else if (objectApiName == 'Kit_Instalacao__c') {
			new IntegracaoSAPKit(ids).execute(null);
		} else if (objectApiName == 'Integradores__c') {
			new IntegracaoSAPIntegrador(ids).execute(null);
		} else if (objectApiName == 'Consultor__c') {
			new IntegracaoSAPConsultor(ids).execute(null);
		} else {
			throw new AuraHandledException(
				'Objeto não suportado para retry SAP: ' + objectApiName
			);
		}

		String safeObject = String.escapeSingleQuotes(objectApiName);
		String query =
			'SELECT SucessoIntegracaoSAP__c, StatusBodyIntegracaoSAP__c' +
			' FROM ' +
			safeObject +
			' WHERE Id = :recordId WITH SECURITY_ENFORCED';
		SObject record = Database.query(query);

		return new SapRetryResult(
			(Boolean) record.get('SucessoIntegracaoSAP__c'),
			(String) record.get('StatusBodyIntegracaoSAP__c')
		);
	}

	public class SapRetryResult {
		@AuraEnabled
		public Boolean success;
		@AuraEnabled
		public String statusBody;

		public SapRetryResult(Boolean success, String statusBody) {
			this.success = success;
			this.statusBody = statusBody;
		}
	}
}
