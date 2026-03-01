public with sharing class CaseBO {
  public static void CreateAttachments(List<Case> newRecords) {
    List<Attachment> attachments = new List<Attachment>();
    for (Case c : newRecords) {
      if (c.Origin != 'Web To Case Integrador')
        continue;

      if (c.CertidaoNegativaTrabalhista__c != null) {
        String base64 = c.CertidaoNegativaTrabalhista__c.substringAfter(
          'base64,'
        );
        try {
          Attachment att = new Attachment(
            Name = 'Certidão Negativa Trabalhista',
            Body = EncodingUtil.base64Decode(base64),
            ParentId = c.Id
          );
          attachments.add(att);
        } catch (System.StringException e) {
          System.debug(e.getMessage());
        }
      }

      if (c.CertidaoNegativaCivel__c != null) {
        String base64 = c.CertidaoNegativaCivel__c.substringAfter('base64,');
        try {
          Attachment att = new Attachment(
            Name = 'Certidão Negativa Civel',
            Body = EncodingUtil.base64Decode(base64),
            ParentId = c.Id
          );
          attachments.add(att);
        } catch (System.StringException e) {
          System.debug(e.getMessage());
        }
      }

      if (c.CertidaoNegativaCriminal__c != null) {
        String base64 = c.CertidaoNegativaCriminal__c.substringAfter('base64,');
        try {
          Attachment att = new Attachment(
            Name = 'Certidão Negativa Criminal',
            Body = EncodingUtil.base64Decode(base64),
            ParentId = c.Id
          );
          attachments.add(att);
        } catch (System.StringException e) {
          System.debug(e.getMessage());
        }
      }

      if (c.CertidaoNegativaFederal__c != null) {
        String base64 = c.CertidaoNegativaFederal__c.substringAfter('base64,');
        try {
          Attachment att = new Attachment(
            Name = 'Certidão Negativa Federal',
            Body = EncodingUtil.base64Decode(base64),
            ParentId = c.Id
          );
          attachments.add(att);
        } catch (System.StringException e) {
          System.debug(e.getMessage());
        }
      }

      if (c.ContratoSocialUltimaAlteracao__c != null) {
        String base64 = c.ContratoSocialUltimaAlteracao__c.substringAfter(
          'base64,'
        );
        try {
          Attachment att = new Attachment(
            Name = 'Contrato Social e Última Alteração',
            Body = EncodingUtil.base64Decode(base64),
            ParentId = c.Id
          );
          attachments.add(att);
        } catch (System.StringException e) {
          System.debug(e.getMessage());
        }
      }

      if (c.RequerimentoDeEmpresario__c != null) {
        String base64 = c.RequerimentoDeEmpresario__c.substringAfter('base64,');
        try {
          Attachment att = new Attachment(
            Name = 'Requerimento de Empresário',
            Body = EncodingUtil.base64Decode(base64),
            ParentId = c.Id
          );
          attachments.add(att);
        } catch (System.StringException e) {
          System.debug(e.getMessage());
        }
      }

      if (c.DocPessoais_Socios_Representantes__c != null) {
        String base64 = c.DocPessoais_Socios_Representantes__c.substringAfter(
          'base64,'
        );
        try {
          Attachment att = new Attachment(
            Name = 'Doc Pessoais Socios/Representantes',
            Body = EncodingUtil.base64Decode(base64),
            ParentId = c.Id
          );
          attachments.add(att);
        } catch (System.StringException e) {
          System.debug(e.getMessage());
        }
      }

      if (c.FichaCadastral__c != null) {
        String base64 = c.FichaCadastral__c.substringAfter('base64,');
        try {
          Attachment att = new Attachment(
            Name = 'Ficha Cadastral',
            Body = EncodingUtil.base64Decode(base64),
            ParentId = c.Id
          );
          attachments.add(att);
        } catch (System.StringException e) {
          System.debug(e.getMessage());
        }
      }

      if (c.ComprovanteEndereco__c != null) {
        String base64 = c.ComprovanteEndereco__c.substringAfter('base64,');
        try {
          Attachment att = new Attachment(
            Name = 'Comprovante de Endereço',
            Body = EncodingUtil.base64Decode(base64),
            ParentId = c.Id
          );
          attachments.add(att);
        } catch (System.StringException e) {
          System.debug(e.getMessage());
        }
      }
    }

    if (!attachments.isEmpty()) {
      insert attachments;
    }
  }

  public static void AssignContactForCase(List<Case> newRecords) {
    Set<String> emails = new Set<String>();
    List<Case> casesToUpdate = new List<Case>();
    List<Contact> newContacts = new List<Contact>();
    System.debug('1');
    System.debug('NewRecords - ' + newRecords);
    for (Case c : newRecords) {
      if (c.Origin != 'Web To Case Integrador')
        continue;
      if (c.EmailIntegradorWeb__c != null)
        emails.add(c.EmailIntegradorWeb__c);
    }

    List<Contact> contacts = [
      SELECT Id, Email
      FROM Contact
      WHERE Email IN :emails
    ];
    Map<String, Id> mapEmailContact = new Map<String, Id>();
    for (Contact c : contacts) {
      mapEmailContact.put(c.Email, c.Id);
    }

    System.debug('Map - ' + mapEmailContact);

    for (Case c : newRecords) {
      System.debug('2');
      if (c.Origin != 'Web To Case Integrador')
        continue;
      if (
        c.EmailIntegradorWeb__c != null &&
        !mapEmailContact.containsKey(c.EmailIntegradorWeb__c)
      ) {
        System.debug('3');
        //c.ContactId = mapEmailContact.get(c.EmailIntegradorWeb__c);
        //}else{
        //casesToUpdate.add(c);
        newContacts.add(
          new Contact(
            Email = c.EmailIntegradorWeb__c,
            LastName = c.NomeIntegradorWeb__c,
            Phone = c.SuppliedPhone
          )
        );
      }
    }

    if (!newContacts.isEmpty()) {
      insert newContacts;
    }

    for (Contact c : newContacts) {
      mapEmailContact.put(c.Email, c.Id);
    }

    for (Case c : newRecords) {
      if (
        c.EmailIntegradorWeb__c != null &&
        mapEmailContact.containsKey(c.EmailIntegradorWeb__c)
      )
        c.ContactId = mapEmailContact.get(c.EmailIntegradorWeb__c);

      //if(mapEmailContact.containsKey(c.EmailIntegradorWeb__c))
      //c.ContactId = mapEmailContact.get(c.EmailIntegradorWeb__c);
    }
  }

  public static void CreateServiceResource(
    Map<Id, Case> newMap,
    Map<Id, Case> oldMap
  ) {
    List<ServiceResource> sr = new List<ServiceResource>();
    List<case> qualificaConsultor = new List<case>();
    Id qualificaConsultorRecordTypeId = SObjectType.Case.getRecordTypeInfosByDeveloperName()
      .get('QualificacaoDeConsultores')
      .getRecordTypeId();
    for (Case c : newMap.values()) {
      if (c.Origin != 'Web To Case Integrador')
        continue;
      if (
        c.Status != null &&
        c.Status == 'Integrador Aprovado' &&
        c.Status != oldMap.get(c.Id).Status
      ) {
        //sr.add(new ServiceResource(Name=c.NomeIntegradorWeb__c, IsActive=true,IsCapacityBased=false,IsOptimizationCapable=false,RelatedRecordId=UserInfo.getUserId()));
        sr.add(
          new ServiceResource(
            Name = c.NomeIntegradorWeb__c,
            IsActive = true,
            IsCapacityBased = false,
            IsOptimizationCapable = false
          )
        );
        if (c.DesejaSeTornarConsultor__c) {
          qualificaConsultor.add(
            new case(
              NomeIntegradorWeb__c = c.NomeIntegradorWeb__c,
              contactId = c.ContactId,
              ParentId = c.Id,
              Origin = c.Origin,
              Subject = 'Qualifica Consultor - ' + c.NomeIntegradorWeb__c,
              RecordTypeID = qualificaConsultorRecordTypeId
            )
          );
        }
      }
    }
    if (!sr.isEmpty())
      insert sr;

    if (!qualificaConsultor.isEmpty())
      insert qualificaConsultor;
  }

  public static void CreateConsultor(
    Map<Id, Case> newMap,
    Map<Id, Case> oldMap
  ) {
    List<Consultor__c> consultores = new List<Consultor__c>();
    Id qualificaConsultorRecordTypeId = SObjectType.Case.getRecordTypeInfosByDeveloperName()
      .get('QualificacaoDeConsultores')
      .getRecordTypeId();
    for (Case c : newMap.values()) {
      if (c.Origin != 'Web To Case Integrador')
        continue;
      if (
        c.Status != null &&
        c.Status == 'Consultor Aprovado' &&
        c.Status != oldMap.get(c.Id).Status &&
        c.RecordTypeID == qualificaConsultorRecordTypeId
      ) {
        consultores.add(new Consultor__c(Name = c.NomeIntegradorWeb__c));
      }
    }
  }

  public static void checkTasksConclusionBeforeStatusChange(
    List<Case> newRecordList,
    Map<Id, Case> oldMap
  ) {
    Map<Id, List<Task>> CaseIdToTaskList = new Map<Id, List<Task>>();

    for (Task task : [
      SELECT Id, Status, WhatId
      FROM Task
      WHERE WhatId IN :newRecordList
    ]) {
      if (!CaseIdToTaskList.containsKey(task.WhatId)) {
        CaseIdToTaskList.put(task.WhatId, new List<Task>());
      }
      CaseIdToTaskList.get(task.WhatId).add(task);
    }

    for (Case caso : newRecordList) {
      if (caso.RecordTypeId != '012U50000005VRNIA2') {
        continue;
      }

      Case oldCase = oldMap.get(caso.Id);
      if (caso.status != oldCase.status && !CaseIdToTaskList.isEmpty()) {
        for (Task task : CaseIdToTaskList.get(caso.Id)) {
          if (!task.Status.equalsIgnoreCase(TaskUtils.STATUS_CONCLUIDO)) {
            //caso.addError('Todas as tarefas existentes para esse caso precisam estar concluídas antes de avançar de fase!');
            break;
          }
        }
      }
    }
  }

  public static void createTaskWhenOwnerChange(
    List<Case> cases,
    Map<Id, Case> oldMap
  ) {
    try {
      List<Task> tasks = new List<Task>();
      Set<Id> caseIds = new Set<Id>();
      Set<Id> oppIds = new Set<Id>();
      Map<Id, Task> caseIdByTask = new Map<Id, Task>();
      Map<Id, Projeto__c> projectByOpportunityId = new Map<Id, Projeto__c>();
      Id caseRecordTypeId = SObjectType.Case.getRecordTypeInfosByDeveloperName()
        .get('Jornada_do_Cliente')
        .getRecordTypeId();

      for (Case caseRecord : cases) {
        if (
          (caseRecord.OwnerId != oldMap.get(caseRecord.Id).OwnerId) &&
          (oldMap.get(caseRecord.Id).OwnerId.getSobjectType() ==
          Group.getSObjectType() &&
          caseRecord.OwnerId.getSobjectType() == User.getSObjectType()) &&
          caseRecord.RecordTypeId == caseRecordTypeId
        ) {
          caseIds.add(caseRecord.Id);
          oppIds.add(caseRecord.Nome_da_Oportunidade__c);
        }
      }

      if (caseIds.isEmpty())
        return;

      List<Task> tasksExist = [
        SELECT Id, WhatId
        FROM Task
        WHERE WhatId IN :caseIds AND Subject = 'Onboarding'
      ];

      List<Case> casesFiltered = [
        SELECT
          Id,
          ContactId,
          AccountId,
          Nome_do_Consultor__r.Name,
          OwnerId,
          ManagerName__c,
          ManagerName__r.Name,
          Nome_da_Oportunidade__r.PotenciaPicoSistema__c
        FROM Case
        WHERE Id IN :caseIds
      ];

      List<Projeto__c> projects = [
        SELECT
          Id,
          Consultor__c,
          GestorObra__c,
          GestorObra__r.Name,
          Oportunidade__c,
          PotenciaPicoSistemakWp__c,
          ConcessionariaEnergia__c
        FROM Projeto__c
        WHERE Oportunidade__c IN :oppIds
      ];

      //Considerando apenas um projeto por Oportunidade
      if (projects != null) {
        for (Projeto__c project : projects) {
          projectByOpportunityId.put(project.Oportunidade__c, project);
        }
      }

      caseIds = new Set<Id>();

      if (!tasksExist?.isEmpty()) {
        for (Task task : tasksExist) {
          caseIds.add(task.WhatId);
        }
      }

      for (Case caseRecord : casesFiltered) {
        //Já existe task para esse Caso
        if (caseIds.contains(caseRecord.Id))
          continue;

        Projeto__c project = projectByOpportunityId.get(
          caseRecord.Nome_da_Oportunidade__c
        );

        Task task = TaskBO.createTask(
          caseRecord.Id,
          'Onboarding',
          'Primeiro contato com o cliente.',
          caseRecord.OwnerId,
          caseRecord.Createddate.Date().addDays(10),
          null
        );
        task.WhoId = caseRecord.ContactId;
        task.NextNotification__c = '5 dias';

        if (project != null) {
          if (project.ConcessionariaEnergia__c != null)
            task.ConcessionariaEnergia__c = project.ConcessionariaEnergia__c;
          if (String.isNotBlank(project.GestorObra__c))
            task.Manager__c = project.GestorObra__r.Name;
          if (project.PotenciaPicoSistemakWp__c != null)
            task.KWP__c = String.valueOf(project.PotenciaPicoSistemakWp__c);
        }
        if (caseRecord.Nome_da_Oportunidade__r?.PotenciaPicoSistema__c != null)
          task.KWP__c = String.valueOf(
            caseRecord.Nome_da_Oportunidade__r.PotenciaPicoSistema__c
          );
        task.Type = 'Jornada do Projeto';
        task.CreateNewTaskAutomatically__c = false;
        tasks.add(task);
      }

      if (!tasks.isEmpty())
        insert tasks;
    } catch (Exception ex) {
      System.debug(
        '##Erro ao criar Caso de Jornada do Projeto: ' + ex.getMessage()
      );
      System.debug('##Stack: ' + ex.getStackTraceString());
      System.debug('##Line: ' + ex.getLineNumber());
    }
  }

  public static void updateStatusWhenOwnerChange(
    List<Case> cases,
    Map<Id, Case> oldMap
  ) {
    try {
      Id caseRecordTypeId = SObjectType.Case.getRecordTypeInfosByDeveloperName()
        .get('Jornada_do_Cliente')
        .getRecordTypeId();

      for (Case caseRecord : cases) {
        if (
          (caseRecord.OwnerId != oldMap.get(caseRecord.Id).OwnerId &&
          caseRecord.OwnerId.getSobjectType() == User.getSObjectType()) &&
          (oldMap.get(caseRecord.Id).OwnerId.getSobjectType() ==
          Group.getSObjectType()) &&
          caseRecord.RecordTypeId == caseRecordTypeId &&
          caseRecord.Status == 'New'
        ) {
          caseRecord.Status = 'Onboarding';
        }
      }
    } catch (Exception ex) {
      System.debug(
        '##Erro ao criar atualizar o owner do Caso de Jornada do Cliente.' +
        ex.getMessage()
      );
      System.debug('##Stack: ' + ex.getStackTraceString());
      System.debug('##Line: ' + ex.getLineNumber());
    }
  }

  public static void assignCaseToMessagingSessions(List<Case> cases) {
    try {
      Id caseRecordTypeId = SObjectType.Case.getRecordTypeInfosByDeveloperName()
        .get('Jornada_do_Cliente')
        .getRecordTypeId();
      Map<Id, Id> contactIds = new Map<Id, Id>();
      Map<Id, Id> accountIds = new Map<Id, Id>();
      Map<Id, Id> opportunityIds = new Map<Id, Id>();

      Map<Id, List<MessagingSession>> sessionsByUser = new Map<Id, List<MessagingSession>>();

      for (Case caseRecord : cases) {
        if (caseRecord.RecordTypeId == caseRecordTypeId) {
          if (String.isNotBlank(caseRecord.ContactId))
            contactIds.put(caseRecord.ContactId, caseRecord.Id);

          if (String.isNotBlank(caseRecord.AccountId))
            accountIds.put(caseRecord.AccountId, caseRecord.Id);

          if (String.isNotBlank(caseRecord.Nome_da_Oportunidade__c))
            opportunityIds.put(
              caseRecord.Nome_da_Oportunidade__c,
              caseRecord.Id
            );
        }
      }

      List<MessagingSession> sessions = [
        SELECT
          Id,
          MessagingEndUserId,
          MessagingEndUser.ContactId,
          MessagingEndUser.AccountId,
          MessagingEndUser.Oportunidade__c,
          CaseId
        FROM MessagingSession
        WHERE
          MessagingEndUser.ContactId IN :contactIds.keySet()
          OR MessagingEndUser.AccountId IN :accountIds.keySet()
          OR MessagingEndUser.Oportunidade__c IN :accountIds.keySet()
      ];

      if (sessions == null)
        return;

      for (MessagingSession session : sessions) {
        Id caseId;

        if (
          String.isNotBlank(session.MessagingEndUser.ContactId) &&
          contactIds.containsKey(session.MessagingEndUser.ContactId)
        ) {
          caseId = contactIds.get(session.MessagingEndUser.ContactId);
        }

        if (
          String.isNotBlank(session.MessagingEndUser.AccountId) &&
          accountIds.containsKey(session.MessagingEndUser.AccountId)
        ) {
          caseId = accountIds.get(session.MessagingEndUser.AccountId);
        }

        if (
          String.isNotBlank(session.MessagingEndUser.Oportunidade__c) &&
          opportunityIds.containsKey(session.MessagingEndUser.Oportunidade__c)
        ) {
          caseId = opportunityIds.get(session.MessagingEndUser.Oportunidade__c);
        }

        session.CaseId = caseId;
      }

      update sessions;
    } catch (Exception ex) {
      System.debug(
        '##Erro ao atribuir messagingSessions para o Caso de Jornada do Cliente.' +
        ex.getMessage()
      );
      System.debug('##Stack: ' + ex.getStackTraceString());
      System.debug('##Line: ' + ex.getLineNumber());
    }
  }
}
