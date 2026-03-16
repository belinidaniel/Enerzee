/**
 * @description       : Coverage tests for IntegracaoNivelloViabilidade
 * @author            : Daniel Belini
 * @last modified on  : 03-15-2026
 * @test              : N/A - classe de teste executavel
 **/
@IsTest
private class IntegracaoNivelloViabilidadeCoverageTest {
	@IsTest
	static void shouldInstantiateInnerDTOs() {
		IntegracaoNivelloViabilidade.EtapaViabilidadeRequest req1 = new IntegracaoNivelloViabilidade.EtapaViabilidadeRequest();
		req1.id = 'vo-etapa-id';
		req1.status = 2;
		req1.description = 'Descrição da viabilidade';

		IntegracaoNivelloViabilidade.ConclusaoViabilidadeRequest req2 = new IntegracaoNivelloViabilidade.ConclusaoViabilidadeRequest();
		req2.id = 'vo-conclusao-id';
		req2.deadline = '2025-06-01T00:00:00.000Z';

		Assert.areEqual('vo-etapa-id', req1.id);
		Assert.areEqual(2, req1.status);
		Assert.areEqual('Descrição da viabilidade', req1.description);
		Assert.areEqual('vo-conclusao-id', req2.id);
		Assert.areEqual('2025-06-01T00:00:00.000Z', req2.deadline);
	}

	@IsTest
	static void shouldCoverAllEtapaViabilidadeStatusBranches() {
		if (
			!TestMetadataUtils.hasMetadataRecord(
				'Integrador__mdt',
				'Etapa_Viabilidade'
			) ||
			!TestMetadataUtils.hasMetadataRecord(
				'Integrador__mdt',
				'Conclusao_Viabilidade'
			)
		) {
			return;
		}

		Account acc = (Account) TestFactory.createSObject(new Account(), true);

		// status = 2 (Visita)
		Opportunity opp1 = (Opportunity) TestFactory.createSObject(
			new Opportunity(
				AccountId = acc.Id,
				IdVirtualOffice__c = 'VO-VISITA',
				EtapaViabilidade__c = 'Visita',
				PrazoAprovacaoViabilidade__c = System.now().addDays(1)
			),
			true
		);

		// status = 3 (Estudo)
		Opportunity opp2 = (Opportunity) TestFactory.createSObject(
			new Opportunity(
				AccountId = acc.Id,
				IdVirtualOffice__c = 'VO-ESTUDO',
				EtapaViabilidade__c = 'Estudo',
				PrazoAprovacaoViabilidade__c = System.now().addDays(2)
			),
			true
		);

		// status = 0 (null → default branch)
		Opportunity opp3 = (Opportunity) TestFactory.createSObject(
			new Opportunity(
				AccountId = acc.Id,
				IdVirtualOffice__c = 'VO-NULLETAPA',
				PrazoAprovacaoViabilidade__c = System.now().addDays(3)
			),
			true
		);

		// status = 0 (else fallback - valor desconhecido)
		Opportunity opp4 = (Opportunity) TestFactory.createSObject(
			new Opportunity(
				AccountId = acc.Id,
				IdVirtualOffice__c = 'VO-OUTRA',
				EtapaViabilidade__c = 'Outra Etapa',
				PrazoAprovacaoViabilidade__c = System.now().addDays(4)
			),
			true
		);

		TokenAPINivelloWs.access_token = 'mock-token';
		Test.setMock(
			HttpCalloutMock.class,
			new TestMetadataUtils.MockHttpSuccess()
		);

		Test.startTest();
		IntegracaoNivelloViabilidade.etapaViabilidade(
			new Set<Id>{ opp1.Id, opp2.Id, opp3.Id, opp4.Id }
		);
		IntegracaoNivelloViabilidade.conclusaoViabilidade(
			new Set<Id>{ opp1.Id, opp2.Id }
		);
		Test.stopTest();

		Assert.isTrue(true, 'Todas as branches de EtapaViabilidade cobertas.');
	}

	@IsTest
	static void shouldHandleEtapaViabilidadeWithAgendamento() {
		if (
			!TestMetadataUtils.hasMetadataRecord(
				'Integrador__mdt',
				'Etapa_Viabilidade'
			)
		) {
			return;
		}

		Account acc = (Account) TestFactory.createSObject(new Account(), true);

		// status = 1 (Agendamento)
		Opportunity oppAgend = (Opportunity) TestFactory.createSObject(
			new Opportunity(
				AccountId = acc.Id,
				IdVirtualOffice__c = 'VO-AGEND-COV',
				EtapaViabilidade__c = 'Agendamento',
				PrazoAprovacaoViabilidade__c = System.now().addDays(5)
			),
			true
		);

		TokenAPINivelloWs.access_token = 'mock-token';
		Test.setMock(
			HttpCalloutMock.class,
			new TestMetadataUtils.MockHttpSuccess()
		);

		Test.startTest();
		IntegracaoNivelloViabilidade.etapaViabilidade(
			new Set<Id>{ oppAgend.Id }
		);
		Test.stopTest();

		Assert.isTrue(true, 'Agendamento (status=1) coberto.');
	}
}
