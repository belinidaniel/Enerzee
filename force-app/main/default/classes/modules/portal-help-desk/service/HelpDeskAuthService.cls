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
        String code = String.valueOf(Math.abs(Crypto.getRandomInteger())).left(6);
        Datetime expiresAt = System.now().addHours(1);
        HelpDeskContactDAO.saveVerification(c, code, expiresAt);

        Messaging.SingleEmailMessage msg = new Messaging.SingleEmailMessage();
        msg.setToAddresses(new String[] { email });
        msg.setSubject('Código de acesso ao portal de casos');
        msg.setPlainTextBody('Seu código de acesso é: ' + code + '. Ele expira em 1 hora.');
        Messaging.sendEmail(new Messaging.SingleEmailMessage[] { msg }, false);
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
