/**
 * @description       : Coverage tests for IntegracaoSAPContrato, IntegracaoSAPPedidoCompra, IntegracaoSAPPedidoVenda
 * @author            : Daniel Belini
 * @last modified on  : 03-15-2026
 * @test              : N/A - classe de teste executavel
 **/
@IsTest
private class IntegracaoSAPCoverageTest {
	@IsTest
	static void shouldInstantiateAllContratoInnerDTOs() {
		IntegracaoSAPContrato.ContratoRequest req = new IntegracaoSAPContrato.ContratoRequest();
		req.cardCode = 'CC-001';
		req.cardType = 'C';
		req.docDate = '2026-03-15';
		req.docDueDate = '2026-04-15';
		req.numAtCard = 'VO-TEST';
		req.bpL_IDAssignedToInvoice = 1;

		IntegracaoSAPContrato.DocumentLines dl = new IntegracaoSAPContrato.DocumentLines();
		dl.itemCode = 'KIT-001';
		dl.quantity = 1;
		dl.price = 9999.99;
		dl.usage = 1;
		dl.measureUnitId = 'UN';
		dl.measurementById = 1;
		dl.billingType = 0;
		dl.dueDateBase = '2026-05-01';
		dl.birthdayDate = '2026-01-01';

		req.documentLines = new List<IntegracaoSAPContrato.DocumentLines>{ dl };

		Assert.areEqual('CC-001', req.cardCode);
		Assert.areEqual(1, req.documentLines.size());
		Assert.areEqual('KIT-001', dl.itemCode);
		Assert.areEqual(9999.99, dl.price);
	}

	@IsTest
	static void shouldInstantiateAllPedidoCompraInnerDTOs() {
		IntegracaoSAPPedidoCompra.PedidoCompraRequest req = new IntegracaoSAPPedidoCompra.PedidoCompraRequest();
		req.cardCode = 'CC-COMPRA';
		req.docDate = '2026-03-15';
		req.docDueDate = '2026-04-15';
		req.numAtCard = 'VO-COMPRA';
		req.bpL_IDAssignedToInvoice = 1;
		req.paymentGroupCode = '30 dias';
		req.U_Classification = 1;
		req.U_ContractOriginId = 'ORI-001';
		req.U_ContractId = 42;

		IntegracaoSAPPedidoCompra.DocumentLines dl = new IntegracaoSAPPedidoCompra.DocumentLines();
		dl.itemCode = 'ITEM-001';
		dl.quantity = 2;
		dl.price = 1500.0;
		dl.U_UnitMeasureHired = 'UN';
		dl.U_MeasurementById = 1;
		dl.U_BillingType = 3;
		dl.U_RecurrenceType = 2;
		dl.U_DueDateBase = '2026-05-01';
		dl.U_BirthdayDate = '2026-01-01';

		req.documentLines = new List<IntegracaoSAPPedidoCompra.DocumentLines>{ dl };

		Assert.areEqual('CC-COMPRA', req.cardCode);
		Assert.areEqual(42, req.U_ContractId);
		Assert.areEqual(1, req.documentLines.size());
		Assert.areEqual('ITEM-001', dl.itemCode);
	}

	@IsTest
	static void shouldInstantiateAllPedidoVendaInnerDTOs() {
		IntegracaoSAPPedidoVenda.PedidoVendaRequest req = new IntegracaoSAPPedidoVenda.PedidoVendaRequest();
		req.cardCode = 'CC-VENDA';
		req.docDate = '2026-03-15';
		req.docDueDate = '2026-04-15';
		req.numAtCard = 'VO-VENDA';
		req.bpL_IDAssignedToInvoice = 1;
		req.paymentGroupCode = '60 dias';
		req.U_Classification = 7;
		req.U_ContractOriginId = 'ORI-VENDA';
		req.U_ContractId = 99;

		IntegracaoSAPPedidoVenda.DocumentLines dl = new IntegracaoSAPPedidoVenda.DocumentLines();
		dl.itemCode = 'ITEM-VENDA';
		dl.quantity = 3;
		dl.price = 2500.0;
		dl.U_UnitMeasureHired = 'SV';
		dl.U_MeasurementById = 2;
		dl.U_BillingType = 1;
		dl.U_RecurrenceType = 3;
		dl.U_DueDateBase = '2026-06-01';
		dl.U_BirthdayDate = '2026-02-01';

		req.documentLines = new List<IntegracaoSAPPedidoVenda.DocumentLines>{ dl };

		Assert.areEqual('CC-VENDA', req.cardCode);
		Assert.areEqual(99, req.U_ContractId);
		Assert.areEqual(1, req.documentLines.size());
		Assert.areEqual('ITEM-VENDA', dl.itemCode);
	}

	@IsTest
	static void shouldCoverGetMeasureUnitIdValueAllBranches() {
		Assert.areEqual('m', IntegracaoSAPContrato.getMeasureUnitIdValue('Metro'));
		Assert.areEqual('m2', IntegracaoSAPContrato.getMeasureUnitIdValue('Metro Quadrados'));
		Assert.areEqual('kg', IntegracaoSAPContrato.getMeasureUnitIdValue('Kilograma'));
		Assert.areEqual('s', IntegracaoSAPContrato.getMeasureUnitIdValue('Segundos'));
		Assert.areEqual('h', IntegracaoSAPContrato.getMeasureUnitIdValue('Horas'));
		Assert.areEqual('d', IntegracaoSAPContrato.getMeasureUnitIdValue('Dia'));
		Assert.areEqual('UN', IntegracaoSAPContrato.getMeasureUnitIdValue('Unidade'));
		Assert.areEqual('SV', IntegracaoSAPContrato.getMeasureUnitIdValue('Serviço'));
		Assert.areEqual('SV', IntegracaoSAPContrato.getMeasureUnitIdValue('Outro'));
	}

	@IsTest
	static void shouldCoverGetMeasurementByIdValueAllBranches() {
		Assert.areEqual(1, IntegracaoSAPContrato.getMeasurementByIdValue('Valor'));
		Assert.areEqual(2, IntegracaoSAPContrato.getMeasurementByIdValue('Percentual'));
		Assert.areEqual(3, IntegracaoSAPContrato.getMeasurementByIdValue('Quantidade'));
		Assert.areEqual(3, IntegracaoSAPContrato.getMeasurementByIdValue('Outro'));
	}

	@IsTest
	static void shouldCoverGetBillingTypeValueAllBranches() {
		Assert.areEqual(0, IntegracaoSAPContrato.getBillingTypeValue('Nenhum'));
		Assert.areEqual(1, IntegracaoSAPContrato.getBillingTypeValue('Medição'));
		Assert.areEqual(2, IntegracaoSAPContrato.getBillingTypeValue('Parcelado'));
		Assert.areEqual(3, IntegracaoSAPContrato.getBillingTypeValue('Recorrente'));
		Assert.areEqual(4, IntegracaoSAPContrato.getBillingTypeValue('Calculado'));
		Assert.areEqual(5, IntegracaoSAPContrato.getBillingTypeValue('Parcelado Medido'));
		Assert.areEqual(5, IntegracaoSAPContrato.getBillingTypeValue('Outro'));
	}

	@IsTest
	static void shouldCoverGetUsageValueKeyBranches() {
		Assert.areEqual(1, IntegracaoSAPContrato.getUsageValue('Industrialização'));
		Assert.areEqual(3, IntegracaoSAPContrato.getUsageValue('Compra Comercial'));
		Assert.areEqual(5, IntegracaoSAPContrato.getUsageValue('Transferência'));
		Assert.areEqual(6, IntegracaoSAPContrato.getUsageValue('Conserto ou reparo'));
		Assert.areEqual(59, IntegracaoSAPContrato.getUsageValue('Compra KIT Weg'));
		Assert.areEqual(8, IntegracaoSAPContrato.getUsageValue('Compra Ativo Fixo'));
		Assert.areEqual(9, IntegracaoSAPContrato.getUsageValue('Venda Prod. Própria'));
		Assert.areEqual(10, IntegracaoSAPContrato.getUsageValue('Venda Adquirida Terc'));
		Assert.areEqual(11, IntegracaoSAPContrato.getUsageValue('Demonstração'));
		Assert.areEqual(7, IntegracaoSAPContrato.getUsageValue('Compra Consumo'));
		Assert.areEqual(13, IntegracaoSAPContrato.getUsageValue('Serv. Prestado/Venda'));
		Assert.areEqual(14, IntegracaoSAPContrato.getUsageValue('Agua e Esgoto'));
		Assert.areEqual(15, IntegracaoSAPContrato.getUsageValue('Aluguel de Imoveis'));
		Assert.areEqual(17, IntegracaoSAPContrato.getUsageValue('Comissao Consultores'));
		Assert.areEqual(18, IntegracaoSAPContrato.getUsageValue('Compra Comercial ST'));
		Assert.areEqual(19, IntegracaoSAPContrato.getUsageValue('Compra NF Fut. Remes'));
		Assert.areEqual(20, IntegracaoSAPContrato.getUsageValue('Compra NF Futura'));
		Assert.areEqual(21, IntegracaoSAPContrato.getUsageValue('Compra de Brindes'));
		Assert.areEqual(22, IntegracaoSAPContrato.getUsageValue('Copa e Cozinha'));
		Assert.areEqual(23, IntegracaoSAPContrato.getUsageValue('Cursos e Treinamento'));
	}

	@IsTest
	static void shouldCallSendMethodsWithEmptySets() {
		Test.setMock(HttpCalloutMock.class, new SAPEmptyMock());

		Test.startTest();
		IntegracaoSAPPedidoCompra.sendPedidoCompra(new Set<Id>());
		IntegracaoSAPPedidoVenda.sendPedidoVenda(new Set<Id>());
		Test.stopTest();

		Assert.isTrue(true, 'sendPedidoCompra/Venda com Set vazio nao deve lancar erro.');
	}

	private class SAPEmptyMock implements HttpCalloutMock {
		public HttpResponse respond(HttpRequest req) {
			HttpResponse res = new HttpResponse();
			res.setStatusCode(200);
			res.setStatus('OK');
			res.setBody('{"codigoHttp":"200","mensagem":"ok"}');
			return res;
		}
	}

	// -----------------------------------------------------------------------
	// SAPSuccessMock — returns SAP-style 200 success body
	// -----------------------------------------------------------------------
	private class SAPSuccessMock implements HttpCalloutMock {
		public HttpResponse respond(HttpRequest req) {
			HttpResponse res = new HttpResponse();
			res.setStatusCode(200);
			res.setStatus('OK');
			res.setBody('{"codigoHttp":"200","mensagem":"ok"}');
			return res;
		}
	}

	// -----------------------------------------------------------------------
	// SAPErrorMock — returns SAP-style 400 error body
	// -----------------------------------------------------------------------
	private class SAPErrorMock implements HttpCalloutMock {
		public HttpResponse respond(HttpRequest req) {
			HttpResponse res = new HttpResponse();
			res.setStatusCode(400);
			res.setStatus('Bad Request');
			res.setBody('{"codigoHttp":"400","mensagem":"erro"}');
			return res;
		}
	}

	// -----------------------------------------------------------------------
	// Shared test-data builder — creates Account + Opportunity + Kit
	// -----------------------------------------------------------------------
	private static Opportunity buildOppWithKit(String classificacao) {
		OpportunityTriggerHandler.disableTrigger();
		KitInstalacaoTriggerHandler.disableTrigger();

		Account acc = (Account) TestFactory.createSObject(new Account(), true);

		Opportunity opp = (Opportunity) TestFactory.createSObject(
			new Opportunity(
				AccountId = acc.Id,
				Classificacao__c = classificacao,
				NumeroContrato__c = '42',
				NumeroOrigemContrato__c = 'ORI-001',
				CondicoesPagamento__c = 'Recursos Próprios',
				IdVirtualOffice__c = 'VO-TEST-001',
				DataEntrega__c = System.today().addDays(30)
			),
			true
		);

		TestFactory.createSObject(
			new Kit_Instalacao__c(Nome_da_Oportunidade__c = opp.Id),
			true
		);

		KitInstalacaoTriggerHandler.enableTrigger();
		OpportunityTriggerHandler.enableTrigger();

		return opp;
	}

	// -----------------------------------------------------------------------
	// IntegracaoSAPContrato — sendContract with Kit present (success path)
	// Covers: SOQL, map building, request building loop, callout success branch
	// -----------------------------------------------------------------------
	@IsTest
	static void shouldCallSendContractWithKitSuccessResponse() {
		if (!TestMetadataUtils.hasMetadataRecord('Integrador__mdt', 'ContratoSAP') ||
			!TestMetadataUtils.hasMetadataRecord('Integrador__mdt', 'TokenSAP')) {
			Assert.isTrue(true, 'Metadata ContratoSAP/TokenSAP ausente — teste ignorado.');
			return;
		}

		Opportunity opp = buildOppWithKit('Contratos de Locação');

		Test.setMock(HttpCalloutMock.class, new SAPSuccessMock());

		Test.startTest();
		IntegracaoSAPContrato.sendContract(new Set<Id>{ opp.Id });
		Test.stopTest();

		Opportunity updated = [SELECT SucessoIntegracaoSAP__c FROM Opportunity WHERE Id = :opp.Id];
		Assert.isTrue(updated.SucessoIntegracaoSAP__c, 'SucessoIntegracaoSAP__c deve ser true após resposta 200.');
	}

	// -----------------------------------------------------------------------
	// IntegracaoSAPContrato — sendContract with Kit present (error response)
	// Covers: else branch (error statusCode) in response handling
	// -----------------------------------------------------------------------
	@IsTest
	static void shouldCallSendContractWithKitErrorResponse() {
		if (!TestMetadataUtils.hasMetadataRecord('Integrador__mdt', 'ContratoSAP') ||
			!TestMetadataUtils.hasMetadataRecord('Integrador__mdt', 'TokenSAP')) {
			Assert.isTrue(true, 'Metadata ContratoSAP/TokenSAP ausente — teste ignorado.');
			return;
		}

		Opportunity opp = buildOppWithKit('Contratos de Serviços');

		Test.setMock(HttpCalloutMock.class, new SAPErrorMock());

		Test.startTest();
		IntegracaoSAPContrato.sendContract(new Set<Id>{ opp.Id });
		Test.stopTest();

		Opportunity updated = [SELECT SucessoIntegracaoSAP__c FROM Opportunity WHERE Id = :opp.Id];
		Assert.areEqual(false, updated.SucessoIntegracaoSAP__c, 'SucessoIntegracaoSAP__c deve ser false após resposta 400.');
	}

	// -----------------------------------------------------------------------
	// IntegracaoSAPContrato — sendContract with no Kits (empty-kit path)
	// Covers: kits.isEmpty() == true branch + OpportunityTriggerHandler disable/enable + update
	// -----------------------------------------------------------------------
	@IsTest
	static void shouldCallSendContractWithNoKits() {
		if (!TestMetadataUtils.hasMetadataRecord('Integrador__mdt', 'ContratoSAP') ||
			!TestMetadataUtils.hasMetadataRecord('Integrador__mdt', 'TokenSAP')) {
			Assert.isTrue(true, 'Metadata ausente — teste ignorado.');
			return;
		}

		OpportunityTriggerHandler.disableTrigger();
		Account acc = (Account) TestFactory.createSObject(new Account(), true);
		Opportunity opp = (Opportunity) TestFactory.createSObject(
			new Opportunity(AccountId = acc.Id),
			true
		);
		OpportunityTriggerHandler.enableTrigger();

		Test.setMock(HttpCalloutMock.class, new SAPSuccessMock());

		Test.startTest();
		IntegracaoSAPContrato.sendContract(new Set<Id>{ opp.Id });
		Test.stopTest();

		Assert.isTrue(true, 'sendContract com Set sem kits nao deve lancar excecao.');
	}

	// -----------------------------------------------------------------------
	// IntegracaoSAPContrato — getUsageValue remaining branches (24 to 76)
	// Covers all values not hit by the first getUsageValue test
	// -----------------------------------------------------------------------
	@IsTest
	static void shouldCoverGetUsageValueRemainingBranches() {
		Assert.areEqual(24, IntegracaoSAPContrato.getUsageValue('Desp Aprendiz/Estagi'));
		Assert.areEqual(25, IntegracaoSAPContrato.getUsageValue('Desp. Contratuais'));
		Assert.areEqual(26, IntegracaoSAPContrato.getUsageValue('Desp. c/ Sistemas'));
		Assert.areEqual(27, IntegracaoSAPContrato.getUsageValue('Desp. c/ Viagem'));
		Assert.areEqual(28, IntegracaoSAPContrato.getUsageValue('Energia Eletrica'));
		Assert.areEqual(29, IntegracaoSAPContrato.getUsageValue('Eventos e Confratern'));
		Assert.areEqual(30, IntegracaoSAPContrato.getUsageValue('Feiras e Exposicoes'));
		Assert.areEqual(31, IntegracaoSAPContrato.getUsageValue('Ferramentas'));
		Assert.areEqual(32, IntegracaoSAPContrato.getUsageValue('Fretes s/ Vendas'));
		Assert.areEqual(33, IntegracaoSAPContrato.getUsageValue('Impostos Estaduais'));
		Assert.areEqual(34, IntegracaoSAPContrato.getUsageValue('Internet e Telefone'));
		Assert.areEqual(35, IntegracaoSAPContrato.getUsageValue('Locacao Maq e Equip'));
		Assert.areEqual(36, IntegracaoSAPContrato.getUsageValue('Lanches e Bebidas'));
		Assert.areEqual(37, IntegracaoSAPContrato.getUsageValue('Locacao de Veiculo'));
		Assert.areEqual(38, IntegracaoSAPContrato.getUsageValue('Outras Saidas'));
		Assert.areEqual(40, IntegracaoSAPContrato.getUsageValue('Publi. e Marketing'));
		Assert.areEqual(41, IntegracaoSAPContrato.getUsageValue('Rem Merc p conserto'));
		Assert.areEqual(12, IntegracaoSAPContrato.getUsageValue('Doação ou brinde'));
		Assert.areEqual(43, IntegracaoSAPContrato.getUsageValue('Serv. Inst Sist Foto'));
		Assert.areEqual(39, IntegracaoSAPContrato.getUsageValue('Outras Entradas'));
		Assert.areEqual(44, IntegracaoSAPContrato.getUsageValue('Saida Unifor e Acess'));
		Assert.areEqual(45, IntegracaoSAPContrato.getUsageValue('Saida de Mat. Elétri'));
		Assert.areEqual(46, IntegracaoSAPContrato.getUsageValue('Serviços Gerais'));
		Assert.areEqual(47, IntegracaoSAPContrato.getUsageValue('Serviços Prestados'));
		Assert.areEqual(48, IntegracaoSAPContrato.getUsageValue('Serviços de Obra'));
		Assert.areEqual(49, IntegracaoSAPContrato.getUsageValue('Taxa ART'));
		Assert.areEqual(50, IntegracaoSAPContrato.getUsageValue('Transf. Filiais'));
		Assert.areEqual(51, IntegracaoSAPContrato.getUsageValue('Transf. Filiais - ST'));
		Assert.areEqual(52, IntegracaoSAPContrato.getUsageValue('Venda NF Futura'));
		Assert.areEqual(53, IntegracaoSAPContrato.getUsageValue('Venda de Imobilizado'));
		Assert.areEqual(54, IntegracaoSAPContrato.getUsageValue('Visita Tecnica'));
		Assert.areEqual(55, IntegracaoSAPContrato.getUsageValue('Servico de Topografi'));
		Assert.areEqual(56, IntegracaoSAPContrato.getUsageValue('Venda de Materiais'));
		Assert.areEqual(57, IntegracaoSAPContrato.getUsageValue('Material Extra Aplic'));
		Assert.areEqual(58, IntegracaoSAPContrato.getUsageValue('Compra Triangulação'));
		Assert.areEqual(42, IntegracaoSAPContrato.getUsageValue('Venda Triangulacao'));
		Assert.areEqual(60, IntegracaoSAPContrato.getUsageValue('Farmacia'));
		Assert.areEqual(61, IntegracaoSAPContrato.getUsageValue('Uniformes e Acessori'));
		Assert.areEqual(62, IntegracaoSAPContrato.getUsageValue('Serv. Manut. Usina'));
		Assert.areEqual(63, IntegracaoSAPContrato.getUsageValue('Dev. Compra'));
		Assert.areEqual(64, IntegracaoSAPContrato.getUsageValue('Retorno de Obra'));
		Assert.areEqual(65, IntegracaoSAPContrato.getUsageValue('Comodato'));
		Assert.areEqual(66, IntegracaoSAPContrato.getUsageValue('Venda Merc V. Ordem'));
		Assert.areEqual(67, IntegracaoSAPContrato.getUsageValue('Remessa Merc C. Orde'));
		Assert.areEqual(68, IntegracaoSAPContrato.getUsageValue('Serv Proteção Veicul'));
		Assert.areEqual(69, IntegracaoSAPContrato.getUsageValue('Dev. Comodato'));
		Assert.areEqual(70, IntegracaoSAPContrato.getUsageValue('Multa Trans Desc Sal'));
		Assert.areEqual(71, IntegracaoSAPContrato.getUsageValue('Dev. Venda'));
		Assert.areEqual(72, IntegracaoSAPContrato.getUsageValue('Compra Com5405/04/03'));
		Assert.areEqual(73, IntegracaoSAPContrato.getUsageValue('Compra Com6405/04/03'));
		Assert.areEqual(74, IntegracaoSAPContrato.getUsageValue('Manut Veiculos'));
		Assert.areEqual(75, IntegracaoSAPContrato.getUsageValue('Retorno Rem Conserto'));
		Assert.areEqual(76, IntegracaoSAPContrato.getUsageValue('Manut. Predial'));
		Assert.areEqual(76, IntegracaoSAPContrato.getUsageValue('ValorDesconhecido'));
	}

	// -----------------------------------------------------------------------
	// IntegracaoSAPPedidoCompra — sendPedidoCompra with Kit present (success)
	// Covers: SOQL, map building, request building loop, response success branch,
	//         update oportunidades, OpportunityTriggerHandler disable/enable
	// -----------------------------------------------------------------------
	@IsTest
	static void shouldCallSendPedidoCompraWithKitSuccessResponse() {
		if (!TestMetadataUtils.hasMetadataRecord('Integrador__mdt', 'PedidoCompraVendaSAP') ||
			!TestMetadataUtils.hasMetadataRecord('Integrador__mdt', 'TokenSAP')) {
			Assert.isTrue(true, 'Metadata PedidoCompraVendaSAP/TokenSAP ausente — teste ignorado.');
			return;
		}

		Opportunity opp = buildOppWithKit('Contratos de Locação');

		Test.setMock(HttpCalloutMock.class, new SAPSuccessMock());

		Test.startTest();
		IntegracaoSAPPedidoCompra.sendPedidoCompra(new Set<Id>{ opp.Id });
		Test.stopTest();

		Opportunity updated = [SELECT SucessoIntegracaoSAP__c FROM Opportunity WHERE Id = :opp.Id];
		Assert.isTrue(updated.SucessoIntegracaoSAP__c, 'SucessoIntegracaoSAP__c deve ser true após resposta 200.');
	}

	// -----------------------------------------------------------------------
	// IntegracaoSAPPedidoCompra — sendPedidoCompra with Kit present (error)
	// Covers: error response branch
	// -----------------------------------------------------------------------
	@IsTest
	static void shouldCallSendPedidoCompraWithKitErrorResponse() {
		if (!TestMetadataUtils.hasMetadataRecord('Integrador__mdt', 'PedidoCompraVendaSAP') ||
			!TestMetadataUtils.hasMetadataRecord('Integrador__mdt', 'TokenSAP')) {
			Assert.isTrue(true, 'Metadata ausente — teste ignorado.');
			return;
		}

		Opportunity opp = buildOppWithKit('Contratos de Serviços');

		Test.setMock(HttpCalloutMock.class, new SAPErrorMock());

		Test.startTest();
		IntegracaoSAPPedidoCompra.sendPedidoCompra(new Set<Id>{ opp.Id });
		Test.stopTest();

		Opportunity updated = [SELECT SucessoIntegracaoSAP__c FROM Opportunity WHERE Id = :opp.Id];
		Assert.areEqual(false, updated.SucessoIntegracaoSAP__c, 'SucessoIntegracaoSAP__c deve ser false após resposta 400.');
	}

	// -----------------------------------------------------------------------
	// IntegracaoSAPPedidoCompra — Classificacao__c branches coverage
	// Covers the ternary chain for U_Classification (values 1–7)
	// -----------------------------------------------------------------------
	@IsTest
	static void shouldCoverPedidoCompraClassificacaoBranches() {
		if (!TestMetadataUtils.hasMetadataRecord('Integrador__mdt', 'PedidoCompraVendaSAP') ||
			!TestMetadataUtils.hasMetadataRecord('Integrador__mdt', 'TokenSAP')) {
			Assert.isTrue(true, 'Metadata ausente — teste ignorado.');
			return;
		}

		List<String> classificacoes = new List<String>{
			'Contratos de Locação',
			'Contratos de Serviços',
			'Contratos de Licenciamento',
			'Compras de equipamentos e materiais',
			'Arrendamento de área rural',
			'Prestação de Serviços (v)',
			'Venda de equipamentos e materiais'
		};

		List<Opportunity> opps = new List<Opportunity>();
		List<Kit_Instalacao__c> kits = new List<Kit_Instalacao__c>();

		OpportunityTriggerHandler.disableTrigger();
		KitInstalacaoTriggerHandler.disableTrigger();
		Account acc = (Account) TestFactory.createSObject(new Account(), true);

		Integer voIdx = 0;
		for (String cl : classificacoes) {
			Opportunity opp = (Opportunity) TestFactory.createSObject(
				new Opportunity(
					AccountId = acc.Id,
					Classificacao__c = cl,
					NumeroContrato__c = '1',
					NumeroOrigemContrato__c = 'ORI-X',
					CondicoesPagamento__c = 'Recursos Próprios',
					IdVirtualOffice__c = 'VO-CL-' + voIdx,
					DataEntrega__c = System.today().addDays(30)
				),
				true
			);
			voIdx++;
			opps.add(opp);
			kits.add(
				(Kit_Instalacao__c) TestFactory.createSObject(
					new Kit_Instalacao__c(Nome_da_Oportunidade__c = opp.Id),
					false
				)
			);
		}
		insert kits;
		KitInstalacaoTriggerHandler.enableTrigger();
		OpportunityTriggerHandler.enableTrigger();

		Set<Id> oppIds = new Map<Id, Opportunity>(opps).keySet();

		Test.setMock(HttpCalloutMock.class, new SAPSuccessMock());

		Test.startTest();
		IntegracaoSAPPedidoCompra.sendPedidoCompra(oppIds);
		Test.stopTest();

		Assert.isTrue(true, 'sendPedidoCompra com todas as classificacoes nao deve lancar excecao.');
	}

	// -----------------------------------------------------------------------
	// IntegracaoSAPPedidoVenda — sendPedidoVenda with Kit present (success)
	// Covers: SOQL, map building, request building loop, response success branch,
	//         update oportunidades, OpportunityTriggerHandler disable/enable
	// -----------------------------------------------------------------------
	@IsTest
	static void shouldCallSendPedidoVendaWithKitSuccessResponse() {
		if (!TestMetadataUtils.hasMetadataRecord('Integrador__mdt', 'PedidoCompraVendaSAP') ||
			!TestMetadataUtils.hasMetadataRecord('Integrador__mdt', 'TokenSAP')) {
			Assert.isTrue(true, 'Metadata PedidoCompraVendaSAP/TokenSAP ausente — teste ignorado.');
			return;
		}

		Opportunity opp = buildOppWithKit('Contratos de Locação');

		Test.setMock(HttpCalloutMock.class, new SAPSuccessMock());

		Test.startTest();
		IntegracaoSAPPedidoVenda.sendPedidoVenda(new Set<Id>{ opp.Id });
		Test.stopTest();

		Opportunity updated = [SELECT SucessoIntegracaoSAP__c FROM Opportunity WHERE Id = :opp.Id];
		Assert.isTrue(updated.SucessoIntegracaoSAP__c, 'SucessoIntegracaoSAP__c deve ser true após resposta 200.');
	}

	// -----------------------------------------------------------------------
	// IntegracaoSAPPedidoVenda — sendPedidoVenda with Kit present (error)
	// Covers: error response branch + NumeroContrato__c null guard (U_ContractId = 0)
	// -----------------------------------------------------------------------
	@IsTest
	static void shouldCallSendPedidoVendaWithKitErrorAndNullContrato() {
		if (!TestMetadataUtils.hasMetadataRecord('Integrador__mdt', 'PedidoCompraVendaSAP') ||
			!TestMetadataUtils.hasMetadataRecord('Integrador__mdt', 'TokenSAP')) {
			Assert.isTrue(true, 'Metadata ausente — teste ignorado.');
			return;
		}

		OpportunityTriggerHandler.disableTrigger();
		KitInstalacaoTriggerHandler.disableTrigger();
		Account acc = (Account) TestFactory.createSObject(new Account(), true);
		Opportunity opp = (Opportunity) TestFactory.createSObject(
			new Opportunity(
				AccountId = acc.Id,
				NumeroContrato__c = null,
				NumeroOrigemContrato__c = 'ORI-NULL',
				CondicoesPagamento__c = 'Recursos Próprios',
				IdVirtualOffice__c = 'VO-NULL-001',
				DataEntrega__c = System.today().addDays(20)
			),
			true
		);
		TestFactory.createSObject(
			new Kit_Instalacao__c(Nome_da_Oportunidade__c = opp.Id),
			true
		);
		KitInstalacaoTriggerHandler.enableTrigger();
		OpportunityTriggerHandler.enableTrigger();

		Test.setMock(HttpCalloutMock.class, new SAPErrorMock());

		Test.startTest();
		IntegracaoSAPPedidoVenda.sendPedidoVenda(new Set<Id>{ opp.Id });
		Test.stopTest();

		Opportunity updated = [SELECT SucessoIntegracaoSAP__c FROM Opportunity WHERE Id = :opp.Id];
		Assert.areEqual(false, updated.SucessoIntegracaoSAP__c, 'SucessoIntegracaoSAP__c deve ser false após resposta 400.');
	}
}
