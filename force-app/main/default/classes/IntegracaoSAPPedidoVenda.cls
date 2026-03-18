/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-18-2026
 * @last modified by  : Daniel Belini
 * @test              : IntegracaoSAPCoverageTest
 **/
public with sharing class IntegracaoSAPPedidoVenda implements Queueable, Database.AllowsCallouts {
  private final Set<Id> recordIds;

  public IntegracaoSAPPedidoVenda(Set<Id> recordIds) {
    this.recordIds = recordIds;
  }

  public void execute(QueueableContext ctx) {
    Map<Id, List<Kit_Instalacao__c>> mapaProdutos = new Map<Id, List<Kit_Instalacao__c>>();

    List<Opportunity> oportunidades = [
      SELECT
        Id,
        Account.SeCPFouCNPJ__c,
        IdVirtualOffice__c,
        Classificacao__c,
        NumeroOrigemContrato__c,
        DataEntrega__c,
        CondicoesPagamento__c,
        FormaPagamento__c,
        ValorTotalProposta__c,
        NumeroContrato__c
      FROM Opportunity
      WHERE Id IN :recordIds
    ];

    List<Kit_Instalacao__c> kits = [
      SELECT
        Id,
        NumeroItemSAP__c,
        ValorKit__c,
        Nome_da_Oportunidade__c,
        Name,
        AniversarioLinha__c,
        Recorrencia__c,
        TipoFaturamento__c,
        TipoMedicao__c,
        UnidadeMedidaLocacao__c,
        VencimentoBase__c,
        Nome_da_Oportunidade__r.ValorTotalProposta__c
      FROM Kit_Instalacao__c
      WHERE Nome_da_Oportunidade__c IN :recordIds
    ];

    if (!kits.isEmpty()) {
      for (Kit_Instalacao__c kit : kits) {
        if (!mapaProdutos.containsKey(kit.Nome_da_Oportunidade__c)) {
          mapaProdutos.put(
            kit.Nome_da_Oportunidade__c,
            new List<Kit_Instalacao__c>{ kit }
          );
        } else {
          mapaProdutos.get(kit.Nome_da_Oportunidade__c).add(kit);
        }
      }

      SAPIntegrationService.EndpointConfig sapConfig = SAPIntegrationService.resolveConfig(
        'PedidoCompraVendaSAP'
      );

      for (Opportunity opp : oportunidades) {
        List<Kit_Instalacao__c> oppKits = mapaProdutos.get(opp.Id);
        PedidoVendaRequest corpoRequisicao = new PedidoVendaRequest();

        if (oppKits != null) {
          corpoRequisicao.cardCode = opp.Account.SeCPFouCNPJ__c;
          corpoRequisicao.docDate = String.valueOf(System.today());
          corpoRequisicao.docDueDate = String.valueOf(opp.DataEntrega__c);
          corpoRequisicao.numAtCard = opp.IdVirtualOffice__c;
          corpoRequisicao.bpL_IDAssignedToInvoice = 1;
          try {
            corpoRequisicao.paymentGroupCode = String.isNotBlank(
                opp.CondicoesPagamento__c
              )
              ? Integer.valueOf(opp.CondicoesPagamento__c)
              : null;
          } catch (TypeException e) {
            corpoRequisicao.paymentGroupCode = null;
          }
          corpoRequisicao.paymentMethod = opp.FormaPagamento__c;
          corpoRequisicao.U_ContractOriginId = opp.NumeroOrigemContrato__c;
          corpoRequisicao.U_ContractId = opp.NumeroContrato__c != null
            ? Integer.valueOf(opp.NumeroContrato__c)
            : 0;
          corpoRequisicao.U_Classification = 7;

          corpoRequisicao.documentLines = new List<DocumentLines>();
          for (Kit_Instalacao__c kit : oppKits) {
            corpoRequisicao.documentLines.add(buildDocumentLine(kit));
          }
        }

        try {
          HttpResponse response = SAPIntegrationService.post(
            JSON.serialize(corpoRequisicao),
            sapConfig,
            'pedidovenda'
          );
          Utils.createLog(
            'IntegracaoSAPPedidoVenda',
            'sendPedidoVenda ' + opp.Id,
            response,
            opp.Id
          );

          if (response.getBody() != null && response.getBody() != '') {
            Map<String, Object> responseBody = (Map<String, Object>) JSON.deserializeUntyped(
              response.getBody()
            );
            Integer statusCode = Integer.valueOf(
              responseBody.get('codigoHttp')
            );

            opp.SucessoIntegracaoSAP__c = SAPIntegrationService.isSuccess(
              statusCode
            );
            opp.StatusBodyIntegracaoSAP__c =
              statusCode +
              ' ' +
              response.getBody() +
              ' ' +
              response.getStatus();
          }
        } catch (Exception e) {
          Utils.createLog(
            'IntegracaoSAPPedidoVenda',
            'sendPedidoVenda ' + opp.Id,
            e,
            opp.Id
          );
          opp.SucessoIntegracaoSAP__c = false;
          opp.StatusBodyIntegracaoSAP__c =
            e.getMessage() +
            ' ' +
            e.getStackTraceString();
        }
      }
    }

    OpportunityTriggerHandler.disableTrigger();
    try {
      update oportunidades;
    } finally {
      OpportunityTriggerHandler.enableTrigger();
    }
  }

  private static DocumentLines buildDocumentLine(Kit_Instalacao__c kit) {
    DocumentLines doc = new DocumentLines();
    doc.itemCode = kit.Name;
    doc.quantity = 1;
    doc.price = kit.Nome_da_Oportunidade__r.ValorTotalProposta__c;
    doc.U_UnitMeasureHired = SAPDocumentLineMapper.getMeasureUnitId(
      kit.UnidadeMedidaLocacao__c
    );
    doc.U_MeasurementById = SAPDocumentLineMapper.getMeasurementById(
      kit.TipoMedicao__c
    );
    doc.U_BillingType = SAPDocumentLineMapper.getBillingType(
      kit.TipoFaturamento__c
    );
    doc.U_RecurrenceType = SAPDocumentLineMapper.getRecurrenceType(
      kit.Recorrencia__c
    );
    doc.U_DueDateBase = String.valueOf(kit.VencimentoBase__c);
    doc.U_BirthdayDate = String.valueOf(kit.AniversarioLinha__c);
    return doc;
  }

  public class PedidoVendaRequest {
    public String cardCode;
    public String docDate;
    public String docDueDate;
    public String numAtCard;
    public Integer bpL_IDAssignedToInvoice;
    public Integer paymentGroupCode;
    public String paymentMethod;
    public Integer U_Classification;
    public String U_ContractOriginId;
    public Integer U_ContractId;
    public List<DocumentLines> documentLines;
  }

  public class DocumentLines {
    public String itemCode;
    public Integer quantity;
    public Double price;
    public String U_UnitMeasureHired;
    public Integer U_MeasurementById;
    public Integer U_BillingType;
    public Integer U_RecurrenceType;
    public String U_DueDateBase;
    public String U_BirthdayDate;
  }
}
