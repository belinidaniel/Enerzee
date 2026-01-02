public with sharing class ProjetoStatusIntegrationService {

    private static final String INTEGRATOR_NAME = 'AlterStatusProject';

    public static void sendStatusUpdates(List<Projeto__c> newList, Map<Id, Projeto__c> oldMap) {
        if (newList == null || newList.isEmpty() || oldMap == null) {
            return;
        }

        List<Id> projectIds = new List<Id>();
        for (Projeto__c proj : newList) {
            Projeto__c oldProj = oldMap.get(proj.Id);
            if (oldProj == null) {
                continue;
            }
            Boolean changed = proj.Status__c != oldProj.Status__c
                || proj.SubStatus__c != oldProj.SubStatus__c
                || proj.MotivoSubStatus__c != oldProj.MotivoSubStatus__c;
            if (changed) {
                projectIds.add(proj.Id);
            }
        }

        if (projectIds.isEmpty()) {
            return;
        }

        send(projectIds);
    }

    private static void send(List<Id> projectIds) {
        if (projectIds == null || projectIds.isEmpty()) {
            return;
        }

        List<Integrador__mdt> integracoes = [
            SELECT URL__c
            FROM Integrador__mdt
            WHERE DeveloperName = :INTEGRATOR_NAME
            LIMIT 1
        ];
        if (integracoes.isEmpty()) {
            return;
        }
        Integrador__mdt integracao = integracoes[0];

        List<Projeto__c> projects = [
            SELECT Id, Status__c, SubStatus__c, MotivoSubStatus__c,
                Oportunidade__c, Oportunidade__r.IdVirtualOffice__c
            FROM Projeto__c
            WHERE Id IN :projectIds
        ];

        for (Projeto__c proj : projects) {
            String proposalId = proj.Oportunidade__r != null ? proj.Oportunidade__r.IdVirtualOffice__c : null;
            if (String.isBlank(proposalId)) {
                continue;
            }

            Integer statusCode = mapStatus(proj.Status__c);
            Integer subStatusCode = mapSubStatus(proj.SubStatus__c);

            Map<String, Object> body = new Map<String, Object>{
                'ProposalId' => proposalId,
                'Status' => statusCode,
                'SubStatus' => subStatusCode,
                'ReasonSubStatus' => proj.MotivoSubStatus__c
            };

            HttpRequest req = new HttpRequest();
            req.setEndpoint(integracao.URL__c);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setBody(JSON.serialize(body));

            try {
                HttpResponse resp = Utils.callIntegrationNivello(req);
                Utils.createLog('ProjetoStatusIntegrationService', 'send', resp, proj.Oportunidade__c);
            } catch (Exception ex) {
                Utils.createLog('ProjetoStatusIntegrationService', 'send', ex, proj.Oportunidade__c);
            }
        }
    }

    @TestVisible
    static Integer mapStatus(String status) {
        if (String.isBlank(status)) {
            return null;
        }
        String norm = status.trim().toLowerCase();
        if (norm == ProjetoUtils.STATUS_PLANEJAMENTO_DE_PROJETO.toLowerCase()) {
            return 1;
        }
        if (norm == ProjetoUtils.STATUS_PROJETOS_EM_ELABORACAO.toLowerCase()
            || norm == ProjetoUtils.STATUS_ELABORACAO_DE_PROJETO.toLowerCase()) {
            return 2;
        }
        if (norm == ProjetoUtils.STATUS_PROJETO_EM_ANALISE.toLowerCase()) {
            return 3;
        }
        if (norm == ProjetoUtils.STATUS_PROJETO_APROVADO.toLowerCase()) {
            return 4;
        }
        // Considera qualquer variação contendo "cancel" como cancelado.
        if (norm.contains('cancel')) {
            return 5;
        }
        return null;
    }

    @TestVisible
    static Integer mapSubStatus(String subStatus) {
        if (String.isBlank(subStatus)) {
            return null;
        }
        String norm = subStatus.trim().toLowerCase();
        if (norm == 'aprovado') {
            return 1;
        }
        if (norm == 'aprovado parcialmente') {
            return 2;
        }
        if (norm == 'cancelado') {
            return 3;
        }
        return null;
    }
}