/**
 * @description       : Coverage tests for IntegracaoNivelloContrato
 * @author            : Daniel Belini
 * @last modified on  : 03-15-2026
 * @test              : N/A - classe de teste executavel
 **/
@IsTest
private class IntegracaoNivelloContratoCoverageTest {
	@IsTest
	static void shouldInstantiateAllInnerDTOs() {
		IntegracaoNivelloContrato.EnviarKitRequest req = new IntegracaoNivelloContrato.EnviarKitRequest();
		req.Id = 'vo-test-id';
		req.PotenciaPicoSistema = 10.5;
		req.ConsumoDesejado = 800.0;
		req.QtdModulos = 20;
		req.StructureType = 2;

		IntegracaoNivelloContrato.Product p1 = new IntegracaoNivelloContrato.Product();
		p1.name = 'Painel 550W';
		p1.Qtd = 20;
		p1.valueUnity = 750.0;
		p1.productFamily = 'Modulos';
		p1.externalId = 'SKU-550W';

		IntegracaoNivelloContrato.Product p2 = new IntegracaoNivelloContrato.Product();
		p2.name = 'Inversor 10kW';
		p2.Qtd = 1;
		p2.valueUnity = 3000.0;
		p2.productFamily = 'Inversores';
		p2.externalId = 'SKU-INV10';

		req.listProducts = new List<IntegracaoNivelloContrato.Product>{ p1, p2 };

		IntegracaoNivelloContrato.EnviarKitResponse resp = new IntegracaoNivelloContrato.EnviarKitResponse();
		resp.Direct = 100.0;
		resp.Pontos = 50.0;
		resp.Rede = 200.0;
		resp.Bdi = 0.15;
		resp.AdditionalFixedCost = 300.0;
		resp.Installation = 500.0;
		resp.FinancialCostWeg = 80.0;

		IntegracaoNivelloContrato.KitResponseWrapper wrapper = new IntegracaoNivelloContrato.KitResponseWrapper();
		wrapper.success = true;
		wrapper.data = resp;

		Assert.areEqual('vo-test-id', req.Id);
		Assert.areEqual(10.5, req.PotenciaPicoSistema);
		Assert.areEqual(2, req.listProducts.size());
		Assert.areEqual('Painel 550W', p1.name);
		Assert.areEqual('SKU-INV10', p2.externalId);
		Assert.areEqual(500.0, resp.Installation);
		Assert.areEqual(80.0, resp.FinancialCostWeg);
		Assert.isTrue(wrapper.success);
	}

	@IsTest
	static void shouldEnviarKitSuccessResponse() {
		if (
			!TestMetadataUtils.hasMetadataRecord('Integrador__mdt', 'updateInfosKit')
		) {
			return;
		}

		TokenAPINivelloWs.access_token = 'mock-token';
		Test.setMock(HttpCalloutMock.class, new NivelloSuccessMock());

		IntegracaoNivelloContrato.EnviarKitRequest req = new IntegracaoNivelloContrato.EnviarKitRequest();
		req.Id = 'vo-success';
		req.PotenciaPicoSistema = 5.0;
		req.ConsumoDesejado = 400.0;
		req.QtdModulos = 10;
		req.StructureType = 1;
		req.listProducts = new List<IntegracaoNivelloContrato.Product>();

		Test.startTest();
		IntegracaoNivelloContrato.EnviarKitResponse result = IntegracaoNivelloContrato.enviarKit(
			req
		);
		Test.stopTest();

		Assert.isNotNull(result, 'Resposta de sucesso nao deve ser nula.');
	}

	@IsTest
	static void shouldEnviarKitErrorResponse() {
		if (
			!TestMetadataUtils.hasMetadataRecord('Integrador__mdt', 'updateInfosKit')
		) {
			return;
		}

		TokenAPINivelloWs.access_token = 'mock-token';
		Test.setMock(HttpCalloutMock.class, new NivelloErrorMock());

		IntegracaoNivelloContrato.EnviarKitRequest req = new IntegracaoNivelloContrato.EnviarKitRequest();
		req.Id = 'vo-error';
		req.listProducts = new List<IntegracaoNivelloContrato.Product>();

		Test.startTest();
		IntegracaoNivelloContrato.EnviarKitResponse result = IntegracaoNivelloContrato.enviarKit(
			req
		);
		Test.stopTest();

		Assert.isNull(result, 'Resposta de erro deve retornar null.');
	}

	@IsTest
	static void shouldEnviarContratoWithMock() {
		if (
			!TestMetadataUtils.hasMetadataRecord('Integrador__mdt', 'ProposalStatus')
		) {
			return;
		}

		Account acc = (Account) TestFactory.createSObject(new Account(), true);
		Opportunity opp = (Opportunity) TestFactory.createSObject(
			new Opportunity(
				AccountId = acc.Id,
				IdVirtualOffice__c = 'VO-CONTRATO-COV',
				LinkContrato__c = 'https://link-contrato.com',
				StageName = OpportunityUtils.STATUS_CONTRATO
			),
			true
		);

		TokenAPINivelloWs.access_token = 'mock-token';
		Test.setMock(HttpCalloutMock.class, new NivelloSuccessMock());

		Test.startTest();
		IntegracaoNivelloContrato.enviarContrato(new Set<Id>{ opp.Id });
		Test.stopTest();

		Opportunity updated = [
			SELECT Id, SucessoIntegracaoNivello__c
			FROM Opportunity
			WHERE Id = :opp.Id
		];
		Assert.isTrue(
			updated.SucessoIntegracaoNivello__c,
			'Integracao deveria ter sucesso.'
		);
	}

	@IsTest
	static void shouldEnviarContratoWithErrorResponse() {
		if (
			!TestMetadataUtils.hasMetadataRecord('Integrador__mdt', 'ProposalStatus')
		) {
			return;
		}

		Account acc = (Account) TestFactory.createSObject(new Account(), true);
		Opportunity opp = (Opportunity) TestFactory.createSObject(
			new Opportunity(
				AccountId = acc.Id,
				IdVirtualOffice__c = 'VO-CONTRATO-ERR',
				StageName = OpportunityUtils.STATUS_CONTRATO
			),
			true
		);

		TokenAPINivelloWs.access_token = 'mock-token';
		Test.setMock(HttpCalloutMock.class, new NivelloErrorMock());

		Test.startTest();
		IntegracaoNivelloContrato.enviarContrato(new Set<Id>{ opp.Id });
		Test.stopTest();

		Opportunity updated = [
			SELECT Id, SucessoIntegracaoNivello__c
			FROM Opportunity
			WHERE Id = :opp.Id
		];
		Assert.isFalse(
			updated.SucessoIntegracaoNivello__c,
			'Integracao deveria falhar com response 400.'
		);
	}

	private class NivelloSuccessMock implements HttpCalloutMock {
		public HttpResponse respond(HttpRequest req) {
			HttpResponse res = new HttpResponse();
			res.setStatusCode(200);
			res.setStatus('OK');
			res.setBody(
				'{"success":true,"data":{"Direct":10.0,"Pontos":5.0,"Rede":20.0,"Bdi":0.1,"AdditionalFixedCost":50.0,"Installation":100.0,"FinancialCostWeg":8.0}}'
			);
			return res;
		}
	}

	private class NivelloErrorMock implements HttpCalloutMock {
		public HttpResponse respond(HttpRequest req) {
			HttpResponse res = new HttpResponse();
			res.setStatusCode(400);
			res.setStatus('Bad Request');
			res.setBody('{"error":"bad request"}');
			return res;
		}
	}
}
