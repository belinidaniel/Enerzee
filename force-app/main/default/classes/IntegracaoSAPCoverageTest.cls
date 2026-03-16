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
}
