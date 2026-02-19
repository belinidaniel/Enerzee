/*
 * Backfill de relacionamentos do ciclo Opportunity > Viability > Projeto > Instalacao
 *
 * Campos cobertos:
 * - Opportunity.MainViability__c
 * - Projeto__c.Oportunidade__c
 * - Projeto__c.Viabilidade__c
 * - Instalacao__c.Projeto__c
 * - Instalacao__c.Oportunidade__c
 * - ViabilityStudy__c.Opportunity__c
 *
 * Uso:
 * 1) Execute com DRY_RUN = true para validar volumes.
 * 2) Troque para DRY_RUN = false para aplicar.
 * 3) Rode novamente enquanto houver pendentes.
 */
Boolean DRY_RUN = true;
Integer LIMIT_PER_STEP = 10000;

System.debug(LoggingLevel.INFO, '=== Backfill Lifecycle START | DRY_RUN=' + DRY_RUN + ' ===');

OpportunityTriggerHandler.disableTrigger();
ProjetoTriggerHandler.disableTrigger();
InstalacaoTriggerHandler.disableTrigger();
ViabilityStudyTriggerHandler.disableTrigger();

try {
    // -----------------------------
    // STEP 1: Opportunity.MainViability__c
    // -----------------------------
    List<Opportunity> oppsWithoutMain = [
        SELECT Id
        FROM Opportunity
        WHERE MainViability__c = null
        LIMIT :LIMIT_PER_STEP
    ];

    Set<Id> oppIdsWithoutMain = new Set<Id>();
    for (Opportunity opp : oppsWithoutMain) {
        oppIdsWithoutMain.add(opp.Id);
    }

    Map<Id, Id> selectedMainByOpp = new Map<Id, Id>();
    if (!oppIdsWithoutMain.isEmpty()) {
        List<ViabilityStudy__c> viabilitiesByOpp = [
            SELECT Id, Opportunity__c, StatusFeasibility__c, LastModifiedDate
            FROM ViabilityStudy__c
            WHERE Opportunity__c IN :oppIdsWithoutMain
            ORDER BY Opportunity__c, LastModifiedDate DESC
        ];

        Map<Id, Id> latestAnyByOpp = new Map<Id, Id>();
        Map<Id, Id> latestFinishedByOpp = new Map<Id, Id>();

        for (ViabilityStudy__c vs : viabilitiesByOpp) {
            if (vs.Opportunity__c == null) {
                continue;
            }

            if (!latestAnyByOpp.containsKey(vs.Opportunity__c)) {
                latestAnyByOpp.put(vs.Opportunity__c, vs.Id);
            }

            if (
                !latestFinishedByOpp.containsKey(vs.Opportunity__c) &&
                vs.StatusFeasibility__c == 'Viabilidade Finalizada'
            ) {
                latestFinishedByOpp.put(vs.Opportunity__c, vs.Id);
            }
        }

        for (Id oppId : oppIdsWithoutMain) {
            Id chosen = latestFinishedByOpp.containsKey(oppId)
                ? latestFinishedByOpp.get(oppId)
                : latestAnyByOpp.get(oppId);
            if (chosen != null) {
                selectedMainByOpp.put(oppId, chosen);
            }
        }
    }

    List<Opportunity> oppsToUpdate = new List<Opportunity>();
    for (Id oppId : selectedMainByOpp.keySet()) {
        oppsToUpdate.add(new Opportunity(
            Id = oppId,
            MainViability__c = selectedMainByOpp.get(oppId)
        ));
    }

    Integer oppSuccess = 0;
    Integer oppError = 0;
    if (!DRY_RUN && !oppsToUpdate.isEmpty()) {
        Database.SaveResult[] sr = Database.update(oppsToUpdate, false);
        for (Integer i = 0; i < sr.size(); i++) {
            if (sr[i].isSuccess()) {
                oppSuccess++;
            } else {
                oppError++;
                for (Database.Error e : sr[i].getErrors()) {
                    System.debug(LoggingLevel.ERROR, 'STEP1 Opportunity Id=' + oppsToUpdate[i].Id + ' | ' + e.getMessage());
                }
            }
        }
    }
    System.debug(LoggingLevel.INFO,
        'STEP1 Opportunity.MainViability__c | candidatos=' + oppsToUpdate.size() +
        ' | sucesso=' + oppSuccess + ' | erro=' + oppError
    );

    // -----------------------------
    // STEP 2: Projeto__c (Oportunidade__c e Viabilidade__c)
    // -----------------------------
    List<Projeto__c> projectCandidates = [
        SELECT Id, Oportunidade__c, Viabilidade__c, Viabilidade__r.Opportunity__c, Instalacao__c
        FROM Projeto__c
        WHERE Oportunidade__c = null OR Viabilidade__c = null
        LIMIT :LIMIT_PER_STEP
    ];

    Set<Id> projectInstallationIds = new Set<Id>();
    Set<Id> projectOppIds = new Set<Id>();
    for (Projeto__c p : projectCandidates) {
        if (p.Instalacao__c != null) {
            projectInstallationIds.add(p.Instalacao__c);
        }
        if (p.Oportunidade__c != null) {
            projectOppIds.add(p.Oportunidade__c);
        }
    }

    Map<Id, Instalacao__c> installationById = new Map<Id, Instalacao__c>();
    if (!projectInstallationIds.isEmpty()) {
        installationById = new Map<Id, Instalacao__c>([
            SELECT Id, Oportunidade__c
            FROM Instalacao__c
            WHERE Id IN :projectInstallationIds
        ]);
    }

    // Recarrega mains reais para as oportunidades envolvidas em projeto.
    // Também considera as oportunidades escolhidas no STEP1 nesta mesma execução.
    Map<Id, Id> mainViabilityByOpp = new Map<Id, Id>();
    if (!projectOppIds.isEmpty()) {
        for (Opportunity opp : [
            SELECT Id, MainViability__c
            FROM Opportunity
            WHERE Id IN :projectOppIds
        ]) {
            if (opp.MainViability__c != null) {
                mainViabilityByOpp.put(opp.Id, opp.MainViability__c);
            }
        }
    }
    for (Id oppIdFromStep1 : selectedMainByOpp.keySet()) {
        mainViabilityByOpp.put(oppIdFromStep1, selectedMainByOpp.get(oppIdFromStep1));
    }

    List<Projeto__c> projectsToUpdate = new List<Projeto__c>();
    for (Projeto__c p : projectCandidates) {
        Id resolvedOpp = p.Oportunidade__c;
        Id resolvedViability = p.Viabilidade__c;

        if (resolvedOpp == null && p.Viabilidade__c != null && p.Viabilidade__r != null && p.Viabilidade__r.Opportunity__c != null) {
            resolvedOpp = p.Viabilidade__r.Opportunity__c;
        }

        if (resolvedOpp == null && p.Instalacao__c != null && installationById.containsKey(p.Instalacao__c)) {
            resolvedOpp = installationById.get(p.Instalacao__c).Oportunidade__c;
        }

        if (resolvedViability == null && resolvedOpp != null && mainViabilityByOpp.containsKey(resolvedOpp)) {
            resolvedViability = mainViabilityByOpp.get(resolvedOpp);
        }

        Boolean changed =
            resolvedOpp != p.Oportunidade__c ||
            resolvedViability != p.Viabilidade__c;

        if (changed) {
            projectsToUpdate.add(new Projeto__c(
                Id = p.Id,
                Oportunidade__c = resolvedOpp,
                Viabilidade__c = resolvedViability
            ));
        }
    }

    Integer projSuccess = 0;
    Integer projError = 0;
    if (!DRY_RUN && !projectsToUpdate.isEmpty()) {
        Database.SaveResult[] sr = Database.update(projectsToUpdate, false);
        for (Integer i = 0; i < sr.size(); i++) {
            if (sr[i].isSuccess()) {
                projSuccess++;
            } else {
                projError++;
                for (Database.Error e : sr[i].getErrors()) {
                    System.debug(LoggingLevel.ERROR, 'STEP2 Projeto Id=' + projectsToUpdate[i].Id + ' | ' + e.getMessage());
                }
            }
        }
    }
    System.debug(LoggingLevel.INFO,
        'STEP2 Projeto (Oportunidade/Viabilidade) | candidatos=' + projectsToUpdate.size() +
        ' | sucesso=' + projSuccess + ' | erro=' + projError
    );

    // -----------------------------
    // STEP 3: Instalacao__c (Projeto__c e Oportunidade__c)
    // -----------------------------
    List<Instalacao__c> installationCandidates = [
        SELECT Id, Projeto__c, Projeto__r.Oportunidade__c, Oportunidade__c, OportunidadeConcluida__c
        FROM Instalacao__c
        WHERE Projeto__c = null
           OR Oportunidade__c = null
           OR (Projeto__c != null AND Projeto__r.Oportunidade__c != Oportunidade__c)
        LIMIT :LIMIT_PER_STEP
    ];

    Set<Id> oppIdsForSingleProjectInference = new Set<Id>();
    for (Instalacao__c inst : installationCandidates) {
        if (inst.Oportunidade__c != null) {
            oppIdsForSingleProjectInference.add(inst.Oportunidade__c);
        }
        if (inst.OportunidadeConcluida__c != null) {
            oppIdsForSingleProjectInference.add(inst.OportunidadeConcluida__c);
        }
    }

    Map<Id, Id> singleProjectByOpp = new Map<Id, Id>();
    Set<Id> oppWithMultipleProjects = new Set<Id>();
    if (!oppIdsForSingleProjectInference.isEmpty()) {
        for (Projeto__c p : [
            SELECT Id, Oportunidade__c
            FROM Projeto__c
            WHERE Oportunidade__c IN :oppIdsForSingleProjectInference
        ]) {
            if (p.Oportunidade__c == null) {
                continue;
            }
            if (oppWithMultipleProjects.contains(p.Oportunidade__c)) {
                continue;
            }
            if (!singleProjectByOpp.containsKey(p.Oportunidade__c)) {
                singleProjectByOpp.put(p.Oportunidade__c, p.Id);
            } else {
                singleProjectByOpp.remove(p.Oportunidade__c);
                oppWithMultipleProjects.add(p.Oportunidade__c);
            }
        }
    }

    List<Instalacao__c> installationsToUpdate = new List<Instalacao__c>();
    for (Instalacao__c inst : installationCandidates) {
        Id resolvedProj = inst.Projeto__c;
        Id resolvedOpp = inst.Oportunidade__c;
        Id resolvedOppDone = inst.OportunidadeConcluida__c;

        if (resolvedProj != null && inst.Projeto__r != null && inst.Projeto__r.Oportunidade__c != null) {
            // Projeto é a fonte de verdade da oportunidade da instalação
            resolvedOpp = inst.Projeto__r.Oportunidade__c;
            if (resolvedOppDone == null) {
                resolvedOppDone = inst.Projeto__r.Oportunidade__c;
            }
        }

        if (resolvedOpp == null && resolvedOppDone != null) {
            resolvedOpp = resolvedOppDone;
        }
        if (resolvedOppDone == null && resolvedOpp != null) {
            resolvedOppDone = resolvedOpp;
        }

        if (resolvedProj == null && resolvedOpp != null && singleProjectByOpp.containsKey(resolvedOpp)) {
            resolvedProj = singleProjectByOpp.get(resolvedOpp);
        }

        Boolean changed =
            resolvedProj != inst.Projeto__c ||
            resolvedOpp != inst.Oportunidade__c ||
            resolvedOppDone != inst.OportunidadeConcluida__c;

        if (changed) {
            installationsToUpdate.add(new Instalacao__c(
                Id = inst.Id,
                Projeto__c = resolvedProj,
                Oportunidade__c = resolvedOpp,
                OportunidadeConcluida__c = resolvedOppDone
            ));
        }
    }

    Integer instSuccess = 0;
    Integer instError = 0;
    if (!DRY_RUN && !installationsToUpdate.isEmpty()) {
        Database.SaveResult[] sr = Database.update(installationsToUpdate, false);
        for (Integer i = 0; i < sr.size(); i++) {
            if (sr[i].isSuccess()) {
                instSuccess++;
            } else {
                instError++;
                for (Database.Error e : sr[i].getErrors()) {
                    System.debug(LoggingLevel.ERROR, 'STEP3 Instalacao Id=' + installationsToUpdate[i].Id + ' | ' + e.getMessage());
                }
            }
        }
    }
    System.debug(LoggingLevel.INFO,
        'STEP3 Instalacao (Projeto/Oportunidade) | candidatos=' + installationsToUpdate.size() +
        ' | sucesso=' + instSuccess + ' | erro=' + instError
    );

    // -----------------------------
    // STEP 4: ViabilityStudy__c.Opportunity__c
    // -----------------------------
    List<ViabilityStudy__c> viabilitiesWithoutOpp = [
        SELECT Id, Opportunity__c
        FROM ViabilityStudy__c
        WHERE Opportunity__c = null
        LIMIT :LIMIT_PER_STEP
    ];

    Set<Id> candidateViabilityIds = new Set<Id>();
    for (ViabilityStudy__c v : viabilitiesWithoutOpp) {
        candidateViabilityIds.add(v.Id);
    }

    Map<Id, Id> viabilityToOpp = new Map<Id, Id>();
    Set<Id> ambiguousViabilityIds = new Set<Id>();

    if (!candidateViabilityIds.isEmpty()) {
        for (Opportunity opp : [
            SELECT Id, MainViability__c
            FROM Opportunity
            WHERE MainViability__c IN :candidateViabilityIds
        ]) {
            Id vId = opp.MainViability__c;
            if (vId == null) {
                continue;
            }
            if (!viabilityToOpp.containsKey(vId)) {
                viabilityToOpp.put(vId, opp.Id);
            } else if (viabilityToOpp.get(vId) != opp.Id) {
                viabilityToOpp.remove(vId);
                ambiguousViabilityIds.add(vId);
            }
        }

        for (Projeto__c p : [
            SELECT Id, Viabilidade__c, Oportunidade__c
            FROM Projeto__c
            WHERE Viabilidade__c IN :candidateViabilityIds
              AND Oportunidade__c != null
        ]) {
            Id vId = p.Viabilidade__c;
            if (vId == null || ambiguousViabilityIds.contains(vId)) {
                continue;
            }
            if (!viabilityToOpp.containsKey(vId)) {
                viabilityToOpp.put(vId, p.Oportunidade__c);
            } else if (viabilityToOpp.get(vId) != p.Oportunidade__c) {
                viabilityToOpp.remove(vId);
                ambiguousViabilityIds.add(vId);
            }
        }
    }

    List<ViabilityStudy__c> viabilitiesToUpdate = new List<ViabilityStudy__c>();
    for (ViabilityStudy__c v : viabilitiesWithoutOpp) {
        if (viabilityToOpp.containsKey(v.Id)) {
            viabilitiesToUpdate.add(new ViabilityStudy__c(
                Id = v.Id,
                Opportunity__c = viabilityToOpp.get(v.Id)
            ));
        }
    }

    Integer viabilitySuccess = 0;
    Integer viabilityError = 0;
    if (!DRY_RUN && !viabilitiesToUpdate.isEmpty()) {
        Database.SaveResult[] sr = Database.update(viabilitiesToUpdate, false);
        for (Integer i = 0; i < sr.size(); i++) {
            if (sr[i].isSuccess()) {
                viabilitySuccess++;
            } else {
                viabilityError++;
                for (Database.Error e : sr[i].getErrors()) {
                    System.debug(LoggingLevel.ERROR, 'STEP4 ViabilityStudy Id=' + viabilitiesToUpdate[i].Id + ' | ' + e.getMessage());
                }
            }
        }
    }
    System.debug(LoggingLevel.INFO,
        'STEP4 ViabilityStudy.Opportunity__c | candidatos=' + viabilitiesToUpdate.size() +
        ' | sucesso=' + viabilitySuccess + ' | erro=' + viabilityError
    );

    // -----------------------------
    // RESUMO DE PENDENCIAS
    // -----------------------------
    Integer pendingOppMain = [
        SELECT COUNT()
        FROM Opportunity
        WHERE MainViability__c = null
          AND Id IN (SELECT Opportunity__c FROM ViabilityStudy__c WHERE Opportunity__c != null)
    ];

    Integer pendingProjects = [
        SELECT COUNT()
        FROM Projeto__c
        WHERE Oportunidade__c = null OR Viabilidade__c = null
    ];

    Integer pendingInstallations = [
        SELECT COUNT()
        FROM Instalacao__c
        WHERE Projeto__c = null
           OR Oportunidade__c = null
           OR (Projeto__c != null AND Projeto__r.Oportunidade__c != Oportunidade__c)
    ];

    Integer pendingViabilities = [
        SELECT COUNT()
        FROM ViabilityStudy__c
        WHERE Opportunity__c = null
    ];

    System.debug(LoggingLevel.INFO,
        'PENDENCIAS | Opp.MainViability=' + pendingOppMain +
        ' | Projeto(opp/viab)=' + pendingProjects +
        ' | Instalacao(proj/opp)=' + pendingInstallations +
        ' | Viability.Opportunity=' + pendingViabilities
    );
} finally {
    OpportunityTriggerHandler.enableTrigger();
    ProjetoTriggerHandler.enableTrigger();
    InstalacaoTriggerHandler.enableTrigger();
    ViabilityStudyTriggerHandler.enableTrigger();
}

System.debug(LoggingLevel.INFO, '=== Backfill Lifecycle END ===');
