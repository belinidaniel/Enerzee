/**
 * @description       : 
 * @author            : Daniel Belini
 * @group             : 
 * @last modified on  : 01-05-2026
 * @last modified by  : Daniel Belini
**/
public without sharing class HelpDeskAuthService {
    public static void requestAccessCode(String email, String firstName, String lastName, String mobilePhone) {
        if (String.isBlank(email)) {
            throw new AuraHandledException('Informe um e-mail.');
        }
        Contact c = HelpDeskContactDAO.findByEmail(email);
        if (c == null) {
            c = HelpDeskContactDAO.createContact(email, firstName, lastName, mobilePhone);
        }
        String code = generateAccessCode();
        Datetime expiresAt = System.now().addHours(1);
        HelpDeskContactDAO.saveVerification(c, code, expiresAt);
        sendAccessCodeEmail(email, code);
    }

    private static String generateAccessCode() {
        Long seed = Long.valueOf(String.valueOf(Crypto.getRandomInteger()));
        if (seed < 0) {
            seed = seed * -1;
        }
        Integer randomValue = Integer.valueOf(Math.mod(seed, 1000000));
        return String.valueOf(randomValue).leftPad(6, '0');
    }

    private static void sendAccessCodeEmail(String email, String code) {
        Messaging.SingleEmailMessage msg = new Messaging.SingleEmailMessage();
        msg.setToAddresses(new String[] { email });
        msg.setSubject('Código de acesso ao portal de casos');
        msg.setPlainTextBody('Seu código de acesso é: ' + code + '. Ele expira em 1 hora.');
        Id orgWideEmailAddressId = resolveOrgWideEmailAddressId();
        if (orgWideEmailAddressId != null) {
            msg.setOrgWideEmailAddressId(orgWideEmailAddressId);
        }

        try {
            Messaging.SendEmailResult[] results = Messaging.sendEmail(new Messaging.SingleEmailMessage[] { msg }, false);
            if (!results.isEmpty() && !results[0].isSuccess()) {
                String errorMessage = 'Falha ao enviar o código por e-mail.';
                List<Messaging.SendEmailError> errors = results[0].getErrors();
                if (errors != null && !errors.isEmpty()) {
                    errorMessage += ' ' + errors[0].getMessage();
                }
                throw new AuraHandledException(errorMessage);
            }
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException('Falha ao enviar o código por e-mail. ' + e.getMessage());
        }
    }

    private static Id resolveOrgWideEmailAddressId() {
        try {
            List<OrgWideEmailAddress> allowAllProfiles = [
                SELECT Id
                FROM OrgWideEmailAddress
                WHERE IsAllowAllProfiles = true
                ORDER BY Address ASC
                LIMIT 1
            ];
            if (!allowAllProfiles.isEmpty()) {
                return allowAllProfiles[0].Id;
            }

            List<OrgWideEmailAddress> anyAddress = [
                SELECT Id
                FROM OrgWideEmailAddress
                ORDER BY Address ASC
                LIMIT 1
            ];
            return anyAddress.isEmpty() ? null : anyAddress[0].Id;
        } catch (Exception e) {
            return null;
        }
    }

    public static Id validateAccessCode(String email, String code) {
        if (String.isBlank(email) || String.isBlank(code)) {
            throw new AuraHandledException('E-mail e código são obrigatórios.');
        }
        Contact c = HelpDeskContactDAO.findByEmail(email);
        if (c == null) {
            throw new AuraHandledException('Contato não encontrado.');
        }
        if (c.Verification_Code__c != code) {
            throw new AuraHandledException('Código inválido.');
        }
        if (c.Verification_Code_Expires__c != null && c.Verification_Code_Expires__c < System.now()) {
            throw new AuraHandledException('Código expirado. Solicite um novo.');
        }
        return c.Id;
    }
}