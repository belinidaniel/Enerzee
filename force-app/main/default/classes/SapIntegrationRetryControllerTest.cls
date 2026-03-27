/**
 * @description       : Tests for SapIntegrationRetryController. Cobre sucesso, falha de integração,
 *                       exceção de callout e objeto não suportado.
 * @author            : Daniel Belini
 * @group             : SAP Integration
 * @last modified on  : 03-27-2026
 * @last modified by  : Daniel Belini
 * @test              : N/A - classe de teste executavel
 **/
@IsTest
private class SapIntegrationRetryControllerTest {

	private static final String SUCCESS_BODY = '{"codigoHttp":201,"mensagem":"Inserido com sucesso","resultado":null}';
	private static final String ERROR_BODY = '{"codigoHttp":404,"mensagem":"Não foi possível cadastrar cliente","resultado":null}';

	// ─── Helpers ──────────────────────────────────────────────────────────────

	private static Account buildAccount() {
		Account acc = new Account(
			Name = 'Retry Teste SAP',
			Email__c = 'retry@teste.com',
			Phone = '11999990000',
			CPF__c = '347.375.188-08',
			SucessoIntegracaoSAP__c = false,
			StatusBodyIntegracaoSAP__c = ERROR_BODY
		);
		insert acc;
		return acc;
	}

	// ─── Tests ────────────────────────────────────────────────────────────────

	@IsTest
	static void retryIntegration_account_successResponse_thenResultSuccessTrue() {
		Account acc = buildAccount();
		Test.setMock(HttpCalloutMock.class, new SAPMock(201, SUCCESS_BODY));

		Test.startTest();
		SapIntegrationRetryController.SapRetryResult result = SapIntegrationRetryController.retryIntegration(
			acc.Id,
			'Account'
		);
		Test.stopTest();

		Assert.isTrue(result.success, 'Success response deve retornar success=true');
		Assert.isNotNull(result.statusBody, 'StatusBody não deve ser nulo');
	}

	@IsTest
	static void retryIntegration_account_errorResponse_thenResultSuccessFalse() {
		Account acc = buildAccount();
		Test.setMock(HttpCalloutMock.class, new SAPMock(404, ERROR_BODY));

		Test.startTest();
		SapIntegrationRetryController.SapRetryResult result = SapIntegrationRetryController.retryIntegration(
			acc.Id,
			'Account'
		);
		Test.stopTest();

		Assert.isFalse(result.success, 'Error response deve retornar success=false');
		Assert.isTrue(
			result.statusBody.contains('404'),
			'StatusBody deve conter o código HTTP'
		);
	}

	@IsTest
	static void retryIntegration_account_calloutException_thenResultSuccessFalse() {
		Account acc = buildAccount();
		Test.setMock(HttpCalloutMock.class, new SAPMock(true));

		Test.startTest();
		SapIntegrationRetryController.SapRetryResult result = SapIntegrationRetryController.retryIntegration(
			acc.Id,
			'Account'
		);
		Test.stopTest();

		Assert.isFalse(
			result.success,
			'Callout exception deve retornar success=false'
		);
	}

	@IsTest
	static void retryIntegration_unsupportedObject_thenThrowsAuraException() {
		Test.startTest();
		try {
			SapIntegrationRetryController.retryIntegration(
				UserInfo.getUserId(),
				'User'
			);
			Assert.fail('Deveria ter lançado exceção para objeto não suportado');
		} catch (AuraHandledException e) {
			Assert.isTrue(
				e.getMessage() != null,
				'AuraHandledException deve ter mensagem'
			);
		}
		Test.stopTest();
	}

	// ─── Mock ─────────────────────────────────────────────────────────────────

	private class SAPMock implements HttpCalloutMock {
		private final Integer statusCode;
		private final String body;
		private final Boolean throwException;

		SAPMock(Integer statusCode, String body) {
			this.statusCode = statusCode;
			this.body = body;
			this.throwException = false;
		}

		SAPMock(Boolean throwException) {
			this.statusCode = 500;
			this.body = '';
			this.throwException = throwException;
		}

		public HttpResponse respond(HttpRequest req) {
			if (throwException) {
				CalloutException e = new CalloutException();
				e.setMessage('SAP connection timeout');
				throw e;
			}
			HttpResponse res = new HttpResponse();
			res.setHeader('Content-Type', 'application/json');
			res.setBody(body);
			res.setStatusCode(statusCode);
			res.setStatus(statusCode == 200 || statusCode == 201 ? 'OK' : 'Error');
			return res;
		}
	}
}
