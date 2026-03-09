/**
 * @description : Batch de retrocarga para preencher campos de datas de engenharia
 *                em registros históricos que passaram pelos marcos antes da automação
 *                existir. Usa LastModifiedDate como data aproximada.
 *                Modos: ViabilityStudy, ProjetoProtocol, Instalacao
 * @author      : Daniel Belini
 **/
global without sharing class EngineeringDateBackfillBatch implements Database.Batchable<SObject> {
  private final String mode;

  global EngineeringDateBackfillBatch(String mode) {
    this.mode = mode;
  }

  global Database.QueryLocator start(Database.BatchableContext bc) {
    if (mode == 'ViabilityStudy') {
      return Database.getQueryLocator(
        'SELECT Id, LastModifiedDate ' +
          'FROM ViabilityStudy__c ' +
          'WHERE StatusFeasibility__c = \'Viabilidade Finalizada\' ' +
          'AND DataConclusaoViabilidade__c = null'
      );
    }
    if (mode == 'ProjetoProtocol') {
      return Database.getQueryLocator(
        'SELECT Id, LastModifiedDate ' +
          'FROM Projeto__c ' +
          'WHERE Status__c = \'Projeto protocolado\' ' +
          'AND DataProtocoloProjeto__c = null'
      );
    }
    if (mode == 'Instalacao') {
      return Database.getQueryLocator(
        'SELECT Id, LastModifiedDate ' +
          'FROM Instalacao__c ' +
          'WHERE Status__c = \'Obra concluída - Aguardando troca de medidor\' ' +
          'AND DataConclusao__c = null'
      );
    }
    throw new IllegalArgumentException(
      'Modo inválido: ' +
        mode +
        '. Use: ViabilityStudy, ProjetoProtocol, Instalacao'
    );
  }

  global void execute(Database.BatchableContext bc, List<SObject> scope) {
    if (scope == null || scope.isEmpty()) {
      return;
    }

    List<SObject> toUpdate = new List<SObject>();

    if (mode == 'ViabilityStudy') {
      for (SObject record : scope) {
        ViabilityStudy__c vs = (ViabilityStudy__c) record;
        vs.DataConclusaoViabilidade__c = Date.valueOf(vs.LastModifiedDate);
        toUpdate.add(vs);
      }
    } else if (mode == 'ProjetoProtocol') {
      for (SObject record : scope) {
        Projeto__c projeto = (Projeto__c) record;
        projeto.DataProtocoloProjeto__c = Date.valueOf(
          projeto.LastModifiedDate
        );
        toUpdate.add(projeto);
      }
    } else if (mode == 'Instalacao') {
      for (SObject record : scope) {
        Instalacao__c inst = (Instalacao__c) record;
        inst.DataConclusao__c = Date.valueOf(inst.LastModifiedDate);
        toUpdate.add(inst);
      }
    }

    Database.update(toUpdate, false);
  }

  global void finish(Database.BatchableContext bc) {
    System.debug('EngineeringDateBackfillBatch concluído — modo: ' + mode);
  }
}
