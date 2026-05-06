/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 05-05-2026
 * @last modified by  : Daniel Belini
 * @test              : KitInstalacaoBOTest, KitInstalacaoTriggerTest
 **/
public without sharing class KitInstalacaoBO {
  private static final String CLASS_NAME = 'KitInstalacaoBO';
  private static final Set<String> EZEECONNECT_RECORD_TYPES = new Set<String>{
    'BowE',
    'Ultragaz',
    'EzeeConnect_Solled',
    'Simplifica',
    'Nextron',
    'Origo'
  };
  private class SendKitUpdateException extends Exception {
  }

  public static void sendKitRecordsToSAP(
    List<Kit_Instalacao__c> newRecordList
  ) {
    if (newRecordList == null || newRecordList.isEmpty()) {
      return;
    }

    try {
      Set<Id> allKitIds = new Set<Id>();
      Set<Id> kitWithItemIds = new Set<Id>();

      for (Kit_Instalacao__c kit : newRecordList) {
        allKitIds.add(kit.Id);
      }

      for (OpportunityLineItem item : [
        SELECT Kit_Instalacao__c
        FROM OpportunityLineItem
        WHERE Kit_Instalacao__c IN :allKitIds
      ]) {
        kitWithItemIds.add(item.Kit_Instalacao__c);
      }

      System.enqueueJob(new IntegracaoSAPKit(kitWithItemIds));
    } catch (Exception e) {
      Utils.createLog(CLASS_NAME, 'sendKitRecordsToSAP', e);
      throw e;
    }
  }

  public static void calculateValueKit(List<Kit_Instalacao__c> newRecordList) {
    if (newRecordList == null || newRecordList.isEmpty()) {
      return;
    }

    try {
      Map<Id, Kit_Instalacao__c> kitsMap = new Map<Id, Kit_Instalacao__c>();
      Map<Id, Id> oppIdToKitId = new Map<Id, Id>();

      for (Kit_Instalacao__c kit : newRecordList) {
        kit.ValorKit__c = 0;
        kitsMap.put(kit.Id, kit);
      }

      System.debug('kitsMap ' + kitsMap);

      // Vamos preencher o Map oppIdToKitId
      for (OpportunityLineItem item : [
        SELECT OpportunityId, Kit_Instalacao__c
        FROM OpportunityLineItem
        WHERE Kit_Instalacao__c IN :kitsMap.keySet()
      ]) {
        oppIdToKitId.put(item.OpportunityId, item.Kit_Instalacao__c);
      }
      System.debug('oppIdToKitId ' + oppIdToKitId);

      Map<Id, Opportunity> oppMap = new Map<Id, Opportunity>(
        [
          SELECT
            Id,
            TipoTelhadoEstrutura__c,
            PotenciaNominalWp__c,
            TotalProdutos__c,
            StatusAprovacaoDesconto__c
          FROM Opportunity
          WHERE Id IN :oppIdToKitId.keySet()
        ]
      );
      System.debug('oppMap ' + oppMap);

      Set<Id> oppIdsToRecallDiscountApproval = new Set<Id>();

      for (OpportunityLineItem item : [
        SELECT OpportunityId, Kit_Instalacao__c, Name, TotalPrice
        FROM OpportunityLineItem
        WHERE Kit_Instalacao__c IN :kitsMap.keySet()
      ]) {
        Decimal valor = (item.TotalPrice != null) ? item.TotalPrice : 0;
        Opportunity relatedOpp = oppMap.get(item.OpportunityId);

        if (
          relatedOpp != null &&
          (item.Name.Contains('SOLO') || item.Name.Contains('REGIAO')) &&
          relatedOpp.TipoTelhadoEstrutura__c == 'Ao Solo' &&
          relatedOpp.PotenciaNominalWp__c != null
        ) {
          valor *= relatedOpp.PotenciaNominalWp__c;
        }

        kitsMap.get(item.Kit_Instalacao__c).ValorKit__c += valor;
      }

      // Agora atualizamos as Oportunidades
      for (Opportunity opp : oppMap.values()) {
        Kit_Instalacao__c kitRelacionado = kitsMap.get(
          oppIdToKitId.get(opp.Id)
        );
        if (kitRelacionado != null) {
          opp.ValorTotalProdutos__c = kitRelacionado.ValorKit__c;
        }
        opp.StatusAprovacaoDesconto__c = null;
        oppIdsToRecallDiscountApproval.add(opp.Id);
        IntegracaoNivelloAprovacaoDesconto.enviarStatusAprovacaoDesconto(
          new Set<Id>{ opp.Id }
        );
      }

      update newRecordList;

      OpportunityTriggerHandler.disableTrigger();
      try {
        update oppMap.values();
      } finally {
        OpportunityTriggerHandler.enableTrigger();
      }

      if (!oppIdsToRecallDiscountApproval.isEmpty()) {
        ApprovalProcessService.recallPendingApprovals(
          oppIdsToRecallDiscountApproval,
          'Approvacao cancelado automaticamente por readequacao no recalculo do kit.'
        );
      }

      recalculateFinancialFields(oppMap.keySet());
    } catch (Exception e) {
      Utils.createLog(CLASS_NAME, 'calculateValueKit', e);
      throw e;
    }
  }

  /**
   * @description Recalculates financial simulation fields on Opportunity after kit value changes.
   *              Re-queries ValorTotalProposta__c (formula field) so it reflects the updated ValorTotalProdutos__c.
   *              Formula: EconomiaAnual = (GRA/2 * Tariff * 0.7) + (GRA/2 * Tariff)
   * @param oppIds Set of Opportunity IDs to recalculate
   */
  @TestVisible
  private static void recalculateFinancialFields(Set<Id> oppIds) {
    if (oppIds == null || oppIds.isEmpty()) {
      return;
    }

    // Re-query to get ValorTotalProposta__c after the previous DML (formula field now recalculated)
    // BowE/EzeeConnect RecordTypes use a separate Flow for financial calculations — skip them here
    List<Opportunity> opportunities = [
      SELECT
        Id,
        RecordType.DeveloperName,
        GeracaoAnualEstimada__c,
        TarifaEnergia__c,
        TarifaForaPonta__c,
        TarifaComTributosB__c,
        GrupoTarifario__c,
        ValorTotalProposta__c
      FROM Opportunity
      WHERE Id IN :oppIds
    ];

    System.debug(
      '[recalculateFinancialFields] oppIds=' +
        oppIds +
        ' | queried=' +
        opportunities.size()
    );

    List<Opportunity> toUpdate = new List<Opportunity>();
    for (Opportunity opp : opportunities) {
      if (EZEECONNECT_RECORD_TYPES.contains(opp.RecordType?.DeveloperName)) {
        continue;
      }
      Decimal geracaoAnual = opp.GeracaoAnualEstimada__c;

      // TarifaEnergia__c is set by EzeeConnect Flow; Solar opps use group-specific tariff fields
      Decimal tariff = opp.TarifaEnergia__c;
      String tariffSource = 'TarifaEnergia__c';
      if ((tariff == null || tariff <= 0) && opp.GrupoTarifario__c != null) {
        tariff = opp.GrupoTarifario__c == 'Grupo A'
          ? opp.TarifaForaPonta__c
          : opp.TarifaComTributosB__c;
        tariffSource = opp.GrupoTarifario__c == 'Grupo A'
          ? 'TarifaForaPonta__c'
          : 'TarifaComTributosB__c';
      }

      System.debug(
        '[recalculateFinancialFields] oppId=' +
          opp.Id +
          ' | GrupoTarifario=' +
          opp.GrupoTarifario__c +
          ' | TarifaEnergia=' +
          opp.TarifaEnergia__c +
          ' | TarifaForaPonta=' +
          opp.TarifaForaPonta__c +
          ' | TarifaComTributosB=' +
          opp.TarifaComTributosB__c +
          ' | tariffResolved=' +
          tariff +
          ' (source=' +
          tariffSource +
          ')' +
          ' | GeracaoAnual=' +
          geracaoAnual +
          ' | ValorTotalProposta=' +
          opp.ValorTotalProposta__c
      );

      if (
        geracaoAnual == null ||
        geracaoAnual <= 0 ||
        tariff == null ||
        tariff <= 0
      ) {
        System.debug(
          '[recalculateFinancialFields] SKIP oppId=' +
            opp.Id +
            ' | geracaoAnual=' +
            geracaoAnual +
            ' | tariff=' +
            tariff
        );
        continue;
      }

      // ((GRA / 2) * tariff * 0.7) + ((GRA / 2) * tariff)
      Decimal economiaAnual = ((geracaoAnual / 2) * tariff * 0.7 +
        (geracaoAnual / 2) * tariff)
        .setScale(2, System.RoundingMode.HALF_UP);

      Opportunity oppToUpdate = new Opportunity(Id = opp.Id);
      oppToUpdate.EconomiaAnualEstimada__c = economiaAnual;

      if (economiaAnual > 0) {
        Decimal investimento = opp.ValorTotalProposta__c != null
          ? opp.ValorTotalProposta__c
          : 0;
        oppToUpdate.EconomiaMensalEstimada__c = (economiaAnual / 12)
          .setScale(2, System.RoundingMode.HALF_UP);
        oppToUpdate.EconomiaAcumulada__c = (economiaAnual * 25 - investimento)
          .setScale(2, System.RoundingMode.HALF_UP);
        if (investimento > 0) {
          oppToUpdate.PaybackAnos__c = (investimento / economiaAnual)
            .setScale(2, System.RoundingMode.HALF_UP);
        }
        System.debug(
          '[recalculateFinancialFields] CALC oppId=' +
            opp.Id +
            ' | EconomiaAnual=' +
            economiaAnual +
            ' | EconomiaMensal=' +
            oppToUpdate.EconomiaMensalEstimada__c +
            ' | EconomiaAcumulada=' +
            oppToUpdate.EconomiaAcumulada__c +
            ' | Payback=' +
            oppToUpdate.PaybackAnos__c +
            ' | investimento=' +
            investimento
        );
      }

      toUpdate.add(oppToUpdate);
    }

    System.debug(
      '[recalculateFinancialFields] toUpdate.size()=' + toUpdate.size()
    );

    if (!toUpdate.isEmpty()) {
      OpportunityTriggerHandler.disableTrigger();
      try {
        update toUpdate;
      } finally {
        OpportunityTriggerHandler.enableTrigger();
      }
    }
  }

  public static void populateKitFields(List<Kit_Instalacao__c> kits) {
    Date today = Date.today();
    Date futureDate = today.addDays(120);

    for (Kit_Instalacao__c kit : kits) {
      kit.UnidadeMedidaLocacao__c = 'Unidade';
      kit.TipoMedicao__c = 'Valor';
      kit.AniversarioLinha__c = futureDate;
      kit.VencimentoBase__c = futureDate;
      kit.TipoFaturamento__c = 'Parcelado';
      kit.Recorrencia__c = 'Mensal';
      kit.CodigoImposto__c = 'Venda NF Futura';
    }
  }

  @future(callout=true)
  public static void SendKitUpdate(Set<Id> kitIds) {
    if (kitIds == null || kitIds.isEmpty()) {
      System.debug('SendKitUpdate called with no kit IDs.');
      return;
    }
    System.debug('SendKitUpdate called for kits: ' + kitIds);

    try {
      // Map Opportunity ID to Kit Instalacao ID for efficient lookup
      Map<Id, Id> oppIdToKitIdMap = new Map<Id, Id>();
      for (Kit_Instalacao__c kit : [
        SELECT Id, Nome_da_Oportunidade__c
        FROM Kit_Instalacao__c
        WHERE Id IN :kitIds AND Nome_da_Oportunidade__c != NULL
      ]) {
        oppIdToKitIdMap.put(kit.Nome_da_Oportunidade__c, kit.Id);
      }

      if (oppIdToKitIdMap.isEmpty()) {
        System.debug('No opportunities found for the given kits.');
        return;
      }

      List<Opportunity> opportunitiesToProcess = [
        SELECT
          Id,
          PotenciaPicoSistema__c,
          NumeroModulos__c,
          IdVirtualOffice__c,
          BDI__c,
          Rede3750__c,
          Pontos__c,
          Direct__c,
          CustoAdicionalFixo__c,
          Instalacao__c,
          CustoFinanceiroWeg__c,
          ConsumoInformadoB__c,
          TipoTelhadoEstrutura__c,
          IsRSD__c,
          (
            SELECT
              ID,
              product2.Name,
              Quantity,
              UnitPrice,
              product2.Family,
              PricebookEntry.ExternalId__c
            FROM OpportunityLineItems
          )
        FROM Opportunity
        WHERE Id IN :oppIdToKitIdMap.keySet() AND Isclosed = FALSE
      ];

      List<Opportunity> opportunitiesToUpdate = new List<Opportunity>();

      for (Opportunity opp : opportunitiesToProcess) {
        try {
          IntegracaoNivelloContrato.EnviarKitRequest requestBody = buildKitRequest(
            opp
          );
          System.debug(
            '[SendKitUpdate] oppId=' +
              opp.Id +
              ' | IdVirtualOffice=' +
              opp.IdVirtualOffice__c +
              ' | request=' +
              JSON.serialize(requestBody)
          );

          Utils.createLog(
            'IdVirtualOffice',
            'IdVirtualOffice - response',
            JSON.serialize(requestBody)
          );
          IntegracaoNivelloContrato.EnviarKitResponse response = IntegracaoNivelloContrato.enviarKit(
            requestBody
          );
          System.debug(
            '[SendKitUpdate] oppId=' +
              opp.Id +
              ' | response=' +
              JSON.serialize(response)
          );
          if (response == null) {
            System.debug(
              '[SendKitUpdate] oppId=' +
                opp.Id +
                ' | response is null after enviarKit. Check [chamadaIntegracao] and [enviarKit] logs for endpoint, statusCode, status, body, and exception details.'
            );
          }

          Id relatedKitId = oppIdToKitIdMap.get(opp.Id);
          opportunitiesToUpdate.add(
            createOpportunityForUpdate(opp, response, relatedKitId)
          );
        } catch (Exception e) {
          Utils.createLog(
            CLASS_NAME,
            'SendKitUpdate - opp ' + opp.Id,
            e,
            opp.Id
          );
        }
      }

      if (!opportunitiesToUpdate.isEmpty()) {
        OpportunityTriggerHandler.disableTrigger();
        try {
          update opportunitiesToUpdate;
        } finally {
          OpportunityTriggerHandler.enableTrigger();
        }
        System.debug(
          opportunitiesToUpdate.size() + ' opportunities updated successfully.'
        );
      } else {
        System.debug('No opportunities were updated.');
      }
    } catch (Exception e) {
      Utils.createLog(CLASS_NAME, 'SendKitUpdate', e);
      // @future should log and finish without rethrow to avoid unhandled async exception e-mails.
    }
  }

  /**
   * @description Builds the request body for the 'enviarKit' callout.
   * @param opp The Opportunity record to build the request from.
   * @return The populated EnviarKitRequest object.
   */
  private static IntegracaoNivelloContrato.EnviarKitRequest buildKitRequest(
    Opportunity opp
  ) {
    IntegracaoNivelloContrato.EnviarKitRequest request = new IntegracaoNivelloContrato.EnviarKitRequest();
    request.Id = opp.IdVirtualOffice__c;
    request.ConsumoDesejado = opp.ConsumoInformadoB__c;
    request.PotenciaPicoSistema = opp.PotenciaPicoSistema__c;
    request.QtdModulos = (opp.NumeroModulos__c != null)
      ? (Integer) opp.NumeroModulos__c
      : 0;
    request.StructureType = getStructureType(opp.TipoTelhadoEstrutura__c);
    request.IsRSD = opp.IsRSD__c;

    request.listProducts = new List<IntegracaoNivelloContrato.Product>();
    for (OpportunityLineItem oli : opp.OpportunityLineItems) {
      IntegracaoNivelloContrato.Product product = new IntegracaoNivelloContrato.Product();
      product.name = oli.Product2.Name;
      product.Qtd = (oli.Quantity != null) ? (Integer) oli.Quantity : 0;
      product.valueUnity = oli.UnitPrice;
      product.productFamily = oli.Product2.Family;

      product.externalId = oli.PricebookEntry != null
        ? oli.PricebookEntry.ExternalId__c
        : null;
      request.listProducts.add(product);
    }
    return request;
  }

  private static Integer getStructureType(String value) {
    if (String.isBlank(value)) {
      return null;
    }

    switch on value {
      when 'Ao Solo', 'Solo' {
        return 1;
      }
      when 'Cerâmico', 'Ceramico' {
        return 2;
      }
      when 'Fibromadeira', 'Fibrocimento (Madeira)' {
        return 3;
      }
      when 'Fibrocimento (Metálico)', 'Fibrocimento (Metalico)' {
        return 5;
      }
      when 'Metálico', 'Metalico' {
        return 6;
      }
      when 'Laje' {
        return 8;
      }
      when 'Zipado' {
        return 9;
      }
      when 'Shingle' {
        return 10;
      }
      when 'CarPort', 'Carport', 'Car Port' {
        return 11;
      }
      when else {
        return null;
      }
    }
  }

  /**
   * @description Creates an Opportunity sObject for update based on the API response.
   * @param originalOpp The original Opportunity record.
   * @param response The response from the 'enviarKit' callout.
   * @param kitId The ID of the related Kit_Instalacao__c record.
   * @return The Opportunity sObject ready for DML update.
   */
  private static Opportunity createOpportunityForUpdate(
    Opportunity originalOpp,
    IntegracaoNivelloContrato.EnviarKitResponse response,
    Id kitId
  ) {
    Opportunity oppToUpdate = new Opportunity(Id = originalOpp.Id);

    // Store previous values
    oppToUpdate.ValorAnteriorBDI__c = originalOpp.BDI__c;
    oppToUpdate.ValorAnteriorRede3750__c = originalOpp.Rede3750__c;
    oppToUpdate.ValorAnteriorPontos__c = originalOpp.Pontos__c;
    oppToUpdate.ValorAnteriorDirect__c = originalOpp.Direct__c;
    if (response == null) {
      Utils.createLog(
        CLASS_NAME,
        'createOpportunityForUpdate',
        'Response is null',
        originalOpp.Id
      );
      return oppToUpdate;
    }

    // Update with new values from the response
    oppToUpdate.BDI__c = response.Bdi;
    oppToUpdate.Rede3750__c = response.Rede;
    oppToUpdate.Pontos__c = response.Pontos;
    oppToUpdate.Direct__c = response.Direct;
    oppToUpdate.CustoAdicionalFixo__c = response.AdditionalFixedCost;
    oppToUpdate.ValorInstalacao__c = response.Installation;
    oppToUpdate.CustoFinanceiroWeg__c = response.FinancialCostWeg;

    oppToUpdate.PropostaAlterada__c = true;

    return oppToUpdate;
  }
}
