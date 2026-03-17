/**
 * @description    : Test class for CompositionBO — covers upsertFromRest scenarios
 * @author         : Daniel Belini
 * @group          :
 * @last modified on  : 03-17-2026
 * @last modified by  : Daniel Belini
 **/
@isTest
private class CompositionBOTest {

	// ─── Helpers ────────────────────────────────────────────────────────────────

	private static Opportunity createOpportunity() {
		Account acc = (Account) TestFactory.createSObject(new Account(), true);
		return (Opportunity) TestFactory.createSObject(
			new Opportunity(AccountId = acc.Id),
			true
		);
	}

	private static OpportunityRecordsTO.SingleOpportunity buildSingleOpportunity(
		String externalId,
		List<OpportunityRecordsTO.Composition> compositions
	) {
		OpportunityRecordsTO.SingleOpportunity so = new OpportunityRecordsTO.SingleOpportunity();
		so.Id = externalId;
		so.Compositions = compositions;
		return so;
	}

	private static OpportunityRecordsTO.Composition buildComposition(
		String externalId,
		String name
	) {
		OpportunityRecordsTO.Composition comp = new OpportunityRecordsTO.Composition();
		comp.ExternalId = externalId;
		comp.Name = name;
		comp.Bdi = 100.0;
		comp.Direct = 200.0;
		comp.Rede = 300.0;
		comp.Pontos = 400.0;
		comp.Installation = 500.0;
		comp.AdditionalFixedCost = 600.0;
		comp.Coupling = 700.0;
		comp.FinancialCostWeg = 800.0;
		comp.TotalProductValue = 900.0;
		return comp;
	}

	// ─── Tests ──────────────────────────────────────────────────────────────────

	/**
	 * Cenário 1: payload com composição nova — deve inserir Composition__c e retornar o Id no mapa
	 */
	@isTest
	static void testUpsertFromRest_newComposition_insertsAndReturnsId() {
		Opportunity opp = createOpportunity();

		String voExternalId = 'VO-001';
		String compExternalId = 'COMP-001';

		OpportunityRecordsTO.Composition comp = buildComposition(compExternalId, 'Composição 01');
		OpportunityRecordsTO.SingleOpportunity so = buildSingleOpportunity(
			voExternalId,
			new List<OpportunityRecordsTO.Composition>{ comp }
		);

		Map<String, Opportunity> externalIdToOpp = new Map<String, Opportunity>{
			voExternalId => opp
		};

		Test.startTest();
		Map<String, Id> result = CompositionBO.upsertFromRest(
			new List<OpportunityRecordsTO.SingleOpportunity>{ so },
			externalIdToOpp
		);
		Test.stopTest();

		Assert.areEqual(1, result.size(), 'Deve retornar 1 entrada no mapa');
		Assert.isTrue(result.containsKey(compExternalId), 'Mapa deve conter o ExternalId da composição');
		Assert.isNotNull(result.get(compExternalId), 'Id da Composition__c não deve ser nulo');

		Composition__c created = [
			SELECT ExternalId__c, Opportunity__c, ByIntegration__c, Bdi__c, Direct__c,
				Network3750__c, Points__c, Installation__c, AdditionalFixedCost__c,
				Coupling__c, FinancialCostWeg__c, TotalProductValue__c
			FROM Composition__c
			WHERE ExternalId__c = :compExternalId
			LIMIT 1
		];

		Assert.areEqual(opp.Id, created.Opportunity__c, 'Composition__c deve estar vinculada à Opportunity');
		Assert.areEqual(true, created.ByIntegration__c, 'ByIntegration__c deve ser true');
		Assert.areEqual(100.0, created.Bdi__c, 'Bdi__c incorreto');
		Assert.areEqual(200.0, created.Direct__c, 'Direct__c incorreto');
		Assert.areEqual(300.0, created.Network3750__c, 'Network3750__c incorreto');
		Assert.areEqual(400.0, created.Points__c, 'Points__c incorreto');
		Assert.areEqual(500.0, created.Installation__c, 'Installation__c incorreto');
		Assert.areEqual(600.0, created.AdditionalFixedCost__c, 'AdditionalFixedCost__c incorreto');
		Assert.areEqual(700.0, created.Coupling__c, 'Coupling__c incorreto');
		Assert.areEqual(800.0, created.FinancialCostWeg__c, 'FinancialCostWeg__c incorreto');
		Assert.areEqual(900.0, created.TotalProductValue__c, 'TotalProductValue__c incorreto');
	}

	/**
	 * Cenário 2: ExternalId já existe — deve atualizar (upsert) e não duplicar
	 */
	@isTest
	static void testUpsertFromRest_existingComposition_updatesAndDoesNotDuplicate() {
		Opportunity opp = createOpportunity();

		String voExternalId = 'VO-002';
		String compExternalId = 'COMP-002';

		// Pré-inserir a composição
		insert new Composition__c(
			ExternalId__c = compExternalId,
			Name = 'Composição Antiga',
			Opportunity__c = opp.Id,
			Bdi__c = 10.0,
			ByIntegration__c = true
		);

		OpportunityRecordsTO.Composition comp = buildComposition(compExternalId, 'Composição Atualizada');
		comp.Bdi = 999.0;
		OpportunityRecordsTO.SingleOpportunity so = buildSingleOpportunity(
			voExternalId,
			new List<OpportunityRecordsTO.Composition>{ comp }
		);

		Map<String, Opportunity> externalIdToOpp = new Map<String, Opportunity>{
			voExternalId => opp
		};

		Test.startTest();
		Map<String, Id> result = CompositionBO.upsertFromRest(
			new List<OpportunityRecordsTO.SingleOpportunity>{ so },
			externalIdToOpp
		);
		Test.stopTest();

		Assert.areEqual(1, result.size(), 'Deve retornar 1 entrada no mapa');

		List<Composition__c> compositions = [
			SELECT Id, Bdi__c
			FROM Composition__c
			WHERE ExternalId__c = :compExternalId
		];

		Assert.areEqual(1, compositions.size(), 'Não deve duplicar a Composition__c');
		Assert.areEqual(999.0, compositions[0].Bdi__c, 'Bdi__c deve ter sido atualizado');
	}

	/**
	 * Cenário 3: payload sem Compositions — Opportunity e OLIs não são afetados, retorna mapa vazio
	 */
	@isTest
	static void testUpsertFromRest_noCompositions_returnsEmptyMap() {
		Opportunity opp = createOpportunity();

		String voExternalId = 'VO-003';
		OpportunityRecordsTO.SingleOpportunity so = buildSingleOpportunity(
			voExternalId,
			null
		);

		Map<String, Opportunity> externalIdToOpp = new Map<String, Opportunity>{
			voExternalId => opp
		};

		Test.startTest();
		Map<String, Id> result = CompositionBO.upsertFromRest(
			new List<OpportunityRecordsTO.SingleOpportunity>{ so },
			externalIdToOpp
		);
		Test.stopTest();

		Assert.areEqual(0, result.size(), 'Mapa deve estar vazio quando não há Compositions');

		Integer count = [SELECT COUNT() FROM Composition__c WHERE Opportunity__c = :opp.Id];
		Assert.areEqual(0, count, 'Nenhuma Composition__c deve ter sido criada');
	}

	/**
	 * Guard: lista nula de SingleOpportunity — retorna mapa vazio sem erro
	 */
	@isTest
	static void testUpsertFromRest_nullInput_returnsEmptyMap() {
		Test.startTest();
		Map<String, Id> result = CompositionBO.upsertFromRest(null, new Map<String, Opportunity>());
		Test.stopTest();

		Assert.areEqual(0, result.size(), 'Mapa deve estar vazio para input nulo');
	}

	/**
	 * Guard: Opportunity não encontrada no mapa — composição é ignorada sem erro
	 */
	@isTest
	static void testUpsertFromRest_opportunityNotInMap_skipsComposition() {
		String voExternalId = 'VO-004';
		String compExternalId = 'COMP-004';

		OpportunityRecordsTO.Composition comp = buildComposition(compExternalId, 'Composição Sem Opp');
		OpportunityRecordsTO.SingleOpportunity so = buildSingleOpportunity(
			voExternalId,
			new List<OpportunityRecordsTO.Composition>{ comp }
		);

		// Mapa vazio — Opportunity não encontrada
		Map<String, Opportunity> externalIdToOpp = new Map<String, Opportunity>();

		Test.startTest();
		Map<String, Id> result = CompositionBO.upsertFromRest(
			new List<OpportunityRecordsTO.SingleOpportunity>{ so },
			externalIdToOpp
		);
		Test.stopTest();

		Assert.areEqual(0, result.size(), 'Mapa deve estar vazio quando Opportunity não está no mapa');
	}

	/**
	 * Guard: ExternalId em branco — composição é ignorada sem erro
	 */
	@isTest
	static void testUpsertFromRest_blankExternalId_skipsComposition() {
		Opportunity opp = createOpportunity();

		String voExternalId = 'VO-005';
		OpportunityRecordsTO.Composition comp = buildComposition('', 'Composição Sem ExternalId');
		OpportunityRecordsTO.SingleOpportunity so = buildSingleOpportunity(
			voExternalId,
			new List<OpportunityRecordsTO.Composition>{ comp }
		);

		Map<String, Opportunity> externalIdToOpp = new Map<String, Opportunity>{
			voExternalId => opp
		};

		Test.startTest();
		Map<String, Id> result = CompositionBO.upsertFromRest(
			new List<OpportunityRecordsTO.SingleOpportunity>{ so },
			externalIdToOpp
		);
		Test.stopTest();

		Assert.areEqual(0, result.size(), 'Composição com ExternalId em branco deve ser ignorada');
	}

	/**
	 * Bulk: múltiplas Opportunities e composições no mesmo payload
	 */
	@isTest
	static void testUpsertFromRest_bulkPayload_insertsAll() {
		Opportunity opp1 = createOpportunity();
		Opportunity opp2 = createOpportunity();

		String voId1 = 'VO-BULK-01';
		String voId2 = 'VO-BULK-02';
		String compId1 = 'COMP-BULK-01';
		String compId2 = 'COMP-BULK-02';

		OpportunityRecordsTO.SingleOpportunity so1 = buildSingleOpportunity(
			voId1,
			new List<OpportunityRecordsTO.Composition>{ buildComposition(compId1, 'Comp Bulk 01') }
		);
		OpportunityRecordsTO.SingleOpportunity so2 = buildSingleOpportunity(
			voId2,
			new List<OpportunityRecordsTO.Composition>{ buildComposition(compId2, 'Comp Bulk 02') }
		);

		Map<String, Opportunity> externalIdToOpp = new Map<String, Opportunity>{
			voId1 => opp1,
			voId2 => opp2
		};

		Test.startTest();
		Map<String, Id> result = CompositionBO.upsertFromRest(
			new List<OpportunityRecordsTO.SingleOpportunity>{ so1, so2 },
			externalIdToOpp
		);
		Test.stopTest();

		Assert.areEqual(2, result.size(), 'Deve retornar 2 entradas no mapa');
		Assert.isTrue(result.containsKey(compId1), 'Mapa deve conter COMP-BULK-01');
		Assert.isTrue(result.containsKey(compId2), 'Mapa deve conter COMP-BULK-02');

		Integer count = [SELECT COUNT() FROM Composition__c WHERE ExternalId__c IN (:compId1, :compId2)];
		Assert.areEqual(2, count, 'Devem existir 2 Composition__c criadas');
	}
}
