public with sharing class IntegracaoSAPPedidoVenda {
  @future(callout=true)
  public static void sendPedidoVenda(Set<Id> triggerIds) {
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
        ValorTotalProposta__c,
        NumeroContrato__c
      FROM Opportunity
      WHERE Id IN :triggerIds
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
      WHERE Nome_da_Oportunidade__c IN :triggerIds
    ];

    if (!kits.isEmpty()) {
      //Montar mapa de referência para os produtos das Oportunidades
      for (Kit_Instalacao__c kit : kits) {
        if (!mapaProdutos.keySet().contains(kits[0].Nome_da_Oportunidade__c)) {
          mapaProdutos.put(
            kit.Nome_da_Oportunidade__c,
            new List<Kit_Instalacao__c>{ kit }
          );
        } else {
          mapaProdutos.get(kit.Nome_da_Oportunidade__c).add(kit);
        }
      }

      for (Opportunity opp : oportunidades) {
        //Somente fazer callout se houver Kits na Oportunidade
        List<Kit_Instalacao__c> oppKits = mapaProdutos.get(opp.Id);
        PedidoVendaRequest corpoRequisicao = new PedidoVendaRequest();

        if (oppKits != null) {
          corpoRequisicao.cardCode = opp.Account.SeCPFouCNPJ__c;
          corpoRequisicao.docDate = String.valueOf(System.today());
          corpoRequisicao.docDueDate = String.valueOf(opp.DataEntrega__c);
          corpoRequisicao.numAtCard = opp.IdVirtualOffice__c;
          corpoRequisicao.bpL_IDAssignedToInvoice = 1;
          corpoRequisicao.paymentGroupCode = opp.CondicoesPagamento__c;
          corpoRequisicao.U_ContractOriginId = opp.NumeroOrigemContrato__c;
          corpoRequisicao.U_ContractId = opp.NumeroContrato__c != null
            ? Integer.valueOf(opp.NumeroContrato__c)
            : 0;

          corpoRequisicao.U_Classification = 7;
          /*opp.Classificacao__c.equalsIgnoreCase('Contratos de Locação') ? 1 :
					opp.Classificacao__c.equalsIgnoreCase('Contratos de Serviços') ? 2 :
					opp.Classificacao__c.equalsIgnoreCase('Contratos de Licenciamento') ? 3 :
					opp.Classificacao__c.equalsIgnoreCase('Compras de equipamentos e materiais') ? 4 :
					opp.Classificacao__c.equalsIgnoreCase('Arrendamento de área rural') ? 5 : 
					opp.Classificacao__c.equalsIgnoreCase('Prestação de Serviços (v)') ? 6 : 
					opp.Classificacao__c.equalsIgnoreCase('Venda de equipamentos e materiais') ? 7 : 7;*/

          //Dados do produto
          corpoRequisicao.documentLines = new List<DocumentLines>();

          for (Kit_Instalacao__c kit : oppKits) {
            DocumentLines doc = new DocumentLines();
            doc.itemCode = kit.Name;
            doc.quantity = 1;
            //doc.price				 = kit.ValorKit__c;
            doc.price = kit.Nome_da_Oportunidade__r.ValorTotalProposta__c;
            doc.U_UnitMeasureHired = kit.UnidadeMedidaLocacao__c.equalsIgnoreCase(
                'Metro'
              )
              ? 'm'
              : kit.UnidadeMedidaLocacao__c.equalsIgnoreCase('Metro Quadrados')
                  ? 'm2'
                  : kit.UnidadeMedidaLocacao__c.equalsIgnoreCase('Kilograma')
                      ? 'kg'
                      : kit.UnidadeMedidaLocacao__c.equalsIgnoreCase('Segundos')
                          ? 's'
                          : kit.UnidadeMedidaLocacao__c.equalsIgnoreCase(
                                'Horas'
                              )
                              ? 'h'
                              : kit.UnidadeMedidaLocacao__c.equalsIgnoreCase(
                                    'Dia'
                                  )
                                  ? 'd'
                                  : kit.UnidadeMedidaLocacao__c.equalsIgnoreCase(
                                        'Unidade'
                                      )
                                      ? 'UN'
                                      : kit.UnidadeMedidaLocacao__c.equalsIgnoreCase(
                                            'Serviço'
                                          )
                                          ? 'SV'
                                          : 'SV';

            doc.U_MeasurementById = kit.TipoMedicao__c.equalsIgnoreCase('Valor')
              ? 1
              : kit.TipoMedicao__c.equalsIgnoreCase('Percentual')
                  ? 2
                  : kit.TipoMedicao__c.equalsIgnoreCase('Quantidade') ? 3 : 3;

            doc.U_BillingType = kit.TipoFaturamento__c.equalsIgnoreCase(
                'Nenhum'
              )
              ? 0
              : kit.TipoFaturamento__c.equalsIgnoreCase('Medição')
                  ? 1
                  : kit.TipoFaturamento__c.equalsIgnoreCase('Parcelado')
                      ? 2
                      : kit.TipoFaturamento__c.equalsIgnoreCase('Recorrente')
                          ? 3
                          : kit.TipoFaturamento__c.equalsIgnoreCase('Calculado')
                              ? 4
                              : kit.TipoFaturamento__c.equalsIgnoreCase(
                                    'Parcelado Medido'
                                  )
                                  ? 5
                                  : 5;

            doc.U_RecurrenceType = kit.Recorrencia__c.equalsIgnoreCase(
                'Indefinida'
              )
              ? 0
              : kit.Recorrencia__c.equalsIgnoreCase('Não se aplica')
                  ? 1
                  : kit.Recorrencia__c.equalsIgnoreCase('Mensal')
                      ? 2
                      : kit.Recorrencia__c.equalsIgnoreCase('Anual')
                          ? 3
                          : kit.Recorrencia__c.equalsIgnoreCase('Bimestral')
                              ? 4
                              : kit.Recorrencia__c.equalsIgnoreCase(
                                    'Trimestral'
                                  )
                                  ? 5
                                  : kit.Recorrencia__c.equalsIgnoreCase(
                                        'Semestral'
                                      )
                                      ? 6
                                      : 6;

            doc.U_DueDateBase = String.valueOf(kit.VencimentoBase__c);
            doc.U_BirthdayDate = String.valueOf(kit.AniversarioLinha__c);

            corpoRequisicao.documentLines.add(doc);
          }
        }

        try {
          HttpResponse response = chamadaIntegracao(
            JSON.serialize(corpoRequisicao),
            'PedidoCompraVendaSAP'
          );
          Utils.createLog(
            'IntegracaoSAPPedidoVenda',
            'sendPedidoVenda ' + opp.Id,
            response,
            opp.Id
          );

          if (response.getBody() != null && response.getBody() != '') {
            Integer[] successSAPResponseCodes = new List<Integer>{
              200,
              201,
              204
            };

            Map<String, Object> responseBody = (Map<String, Object>) JSON.deserializeUntyped(
              response.getBody()
            );
            Integer statusCode = Integer.valueOf(
              responseBody.get('codigoHttp')
            );

            //Sucesso
            if (successSAPResponseCodes.contains(statusCode)) {
              System.debug('SUCCESS');
              opp.SucessoIntegracaoSAP__c = true;
            }
            //Erro
            else {
              System.debug('ERROR');
              opp.SucessoIntegracaoSAP__c = false;
            }
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
    update oportunidades;
    OpportunityTriggerHandler.enableTrigger();
  }

  private static HttpResponse chamadaIntegracao(
    String body,
    String endpointName
  ) {
    Integrador__mdt parametrosIntegracao = [
      SELECT Id, URL__c
      FROM Integrador__mdt
      WHERE DeveloperName = :endpointName
    ];

    String tokenSAP = [
      SELECT Id, LastToken__c
      FROM Integrador__mdt
      WHERE DeveloperName = 'TokenSAP'
    ]
    .LastToken__c;

    Http httpObj = new Http();
    HttpRequest request = new HttpRequest();

    request.setEndpoint(parametrosIntegracao.URL__c + 'pedidovenda');
    request.setMethod('POST');
    request.setHeader('Content-Type', 'application/json');
    request.setHeader('Authorization', 'Bearer ' + tokenSAP);
    request.setBody(body);

    return Utils.callIntegrationSAP(request);
  }

  public class PedidoVendaRequest {
    public String cardCode;
    public String docDate;
    public String docDueDate;
    public String numAtCard;
    public Integer bpL_IDAssignedToInvoice;
    public String paymentGroupCode;
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
