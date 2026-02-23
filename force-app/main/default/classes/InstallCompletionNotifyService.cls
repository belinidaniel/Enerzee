public with sharing class InstallCompletionNotifyService {
    private static final String CONFIG_DEVELOPER_NAME = 'INSTALLATION_COMPLETION_NOTIFY';

    @TestVisible
    private static NotificationConfig testConfigOverride;

    public static void notifyOnCompletion(List<Instalacao__c> newRecords, Map<Id, Instalacao__c> oldMap) {
        if (newRecords == null || newRecords.isEmpty()) {
            return;
        }

        NotificationConfig config = loadConfig();
        if (config == null || !config.isActive || config.completedStatuses.isEmpty() || config.recipientEmails.isEmpty()) {
            return;
        }

        Set<Id> installationIds = new Set<Id>();
        for (Instalacao__c current : newRecords) {
            Instalacao__c previous = oldMap != null ? oldMap.get(current.Id) : null;
            if (isCompletionTransition(previous, current, config.completedStatuses)) {
                installationIds.add(current.Id);
            }
        }
        if (installationIds.isEmpty()) {
            return;
        }

        Map<Id, Instalacao__c> installationsById = new Map<Id, Instalacao__c>([
            SELECT Id, Name, Status__c, ClienteConta__r.Name, Oportunidade__c,
                Oportunidade__r.Name, Oportunidade__r.NumeroInstalacao__c, Oportunidade__r.Account.Name
            FROM Instalacao__c
            WHERE Id IN :installationIds
        ]);

        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        for (Id installationId : installationIds) {
            Instalacao__c installation = installationsById.get(installationId);
            if (installation == null) {
                continue;
            }

            Messaging.SingleEmailMessage message = new Messaging.SingleEmailMessage();
            message.setToAddresses(config.recipientEmails);
            message.setSubject(buildSubject(installation));
            message.setHtmlBody(buildBody(installation));
            message.setUseSignature(false);
            message.setSaveAsActivity(false);
            emails.add(message);
        }

        if (!emails.isEmpty()) {
            Messaging.sendEmail(emails, false);
        }
    }

    @TestVisible
    static Boolean isCompletionTransition(
        Instalacao__c previous,
        Instalacao__c current,
        Set<String> completedStatuses
    ) {
        if (current == null || completedStatuses == null || completedStatuses.isEmpty()) {
            return false;
        }

        String currentStatus = normalizeStatus(current.Status__c);
        if (String.isBlank(currentStatus) || !completedStatuses.contains(currentStatus)) {
            return false;
        }

        String previousStatus = previous != null ? normalizeStatus(previous.Status__c) : null;
        return String.isBlank(previousStatus) || !completedStatuses.contains(previousStatus);
    }

    private static NotificationConfig loadConfig() {
        if (Test.isRunningTest() && testConfigOverride != null) {
            return testConfigOverride;
        }
        if (Test.isRunningTest() && testConfigOverride == null) {
            return null;
        }

        List<InstallationCompletionNotification__mdt> configs = [
            SELECT IsActive__c, CompletedStatuses__c, RecipientEmails__c
            FROM InstallationCompletionNotification__mdt
            WHERE DeveloperName = :CONFIG_DEVELOPER_NAME
            LIMIT 1
        ];
        if (configs.isEmpty()) {
            return null;
        }

        InstallationCompletionNotification__mdt record = configs[0];
        NotificationConfig config = new NotificationConfig();
        config.isActive = record.IsActive__c == true;
        config.completedStatuses = parseStatuses(record.CompletedStatuses__c);
        config.recipientEmails = parseRecipients(record.RecipientEmails__c);
        return config;
    }

    private static Set<String> parseStatuses(String rawStatuses) {
        Set<String> statuses = new Set<String>();
        if (String.isBlank(rawStatuses)) {
            return statuses;
        }

        for (String token : rawStatuses.split('[;,\\n\\r]+')) {
            String normalized = normalizeStatus(token);
            if (!String.isBlank(normalized)) {
                statuses.add(normalized);
            }
        }
        return statuses;
    }

    private static List<String> parseRecipients(String rawRecipients) {
        Set<String> unique = new Set<String>();
        if (String.isBlank(rawRecipients)) {
            return new List<String>();
        }

        for (String token : rawRecipients.split('[;,\\n\\r]+')) {
            String email = token != null ? token.trim() : null;
            if (String.isNotBlank(email)) {
                unique.add(email);
            }
        }
        return new List<String>(unique);
    }

    private static String buildSubject(Instalacao__c installation) {
        String installationLabel = String.isNotBlank(installation.Oportunidade__r != null ? installation.Oportunidade__r.NumeroInstalacao__c : null)
            ? installation.Oportunidade__r.NumeroInstalacao__c
            : installation.Name;
        if (String.isBlank(installationLabel)) {
            installationLabel = String.valueOf(installation.Id);
        }
        return 'Instalação concluída: ' + installationLabel;
    }

    private static String buildBody(Instalacao__c installation) {
        String accountName = (installation.Oportunidade__r != null && installation.Oportunidade__r.Account != null)
            ? installation.Oportunidade__r.Account.Name
            : null;
        if (String.isBlank(accountName) && installation.ClienteConta__r != null) {
            accountName = installation.ClienteConta__r.Name;
        }

        String installationLabel = String.isNotBlank(installation.Oportunidade__r != null ? installation.Oportunidade__r.NumeroInstalacao__c : null)
            ? installation.Oportunidade__r.NumeroInstalacao__c
            : installation.Name;
        if (String.isBlank(installationLabel)) {
            installationLabel = String.valueOf(installation.Id);
        }

        String opportunityName = installation.Oportunidade__r != null ? installation.Oportunidade__r.Name : null;
        String status = String.isNotBlank(installation.Status__c) ? installation.Status__c : '-';
        String nowValue = Datetime.now().format('dd/MM/yyyy HH:mm');
        String recordUrl = URL.getOrgDomainUrl().toExternalForm() + '/' + installation.Id;
        String opportunityUrl = installation.Oportunidade__c != null
            ? URL.getOrgDomainUrl().toExternalForm() + '/' + installation.Oportunidade__c
            : null;

        return ''
            + '<p>Instalação concluída.</p>'
            + '<p><strong>Instalação:</strong> ' + escapeHtml(installationLabel) + '</p>'
            + '<p><strong>Conta:</strong> ' + escapeHtml(String.isNotBlank(accountName) ? accountName : '-') + '</p>'
            + '<p><strong>Oportunidade:</strong> '
            + (
                String.isNotBlank(opportunityName) && String.isNotBlank(opportunityUrl)
                    ? '<a href="' + escapeHtml(opportunityUrl) + '">' + escapeHtml(opportunityName) + '</a>'
                    : escapeHtml(String.isNotBlank(opportunityName) ? opportunityName : '-')
            )
            + '</p>'
            + '<p><strong>Status:</strong> ' + escapeHtml(status) + '</p>'
            + '<p><strong>Data/Hora:</strong> ' + escapeHtml(nowValue) + '</p>'
            + '<p><strong>Registro:</strong> <a href="' + escapeHtml(recordUrl) + '">' + escapeHtml(recordUrl) + '</a></p>';
    }

    private static String normalizeStatus(String value) {
        if (String.isBlank(value)) {
            return null;
        }
        String normalized = value.toLowerCase().trim();
        normalized = normalized
            .replaceAll('[áàãâä]', 'a')
            .replaceAll('[éèêë]', 'e')
            .replaceAll('[íìîï]', 'i')
            .replaceAll('[óòõôö]', 'o')
            .replaceAll('[úùûü]', 'u')
            .replaceAll('[ç]', 'c');
        normalized = normalized.replaceAll('\\s+', ' ');
        return normalized;
    }

    private static String escapeHtml(String value) {
        if (value == null) {
            return '';
        }
        String escaped = value.replace('&', '&amp;');
        escaped = escaped.replace('<', '&lt;');
        escaped = escaped.replace('>', '&gt;');
        escaped = escaped.replace('"', '&quot;');
        escaped = escaped.replace('\'', '&#39;');
        return escaped;
    }

    @TestVisible
    static void setTestConfig(Boolean isActive, String statuses, String recipients) {
        NotificationConfig config = new NotificationConfig();
        config.isActive = isActive == true;
        config.completedStatuses = parseStatuses(statuses);
        config.recipientEmails = parseRecipients(recipients);
        testConfigOverride = config;
    }

    @TestVisible
    static void clearTestConfig() {
        testConfigOverride = null;
    }

    private class NotificationConfig {
        public Boolean isActive;
        public Set<String> completedStatuses;
        public List<String> recipientEmails;
    }
}
