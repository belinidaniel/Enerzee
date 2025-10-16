/**
 * @description       : Detecta se uma conversa é remarketing usando Named Credential
 * @author            : Daniel Belini
 * @last modified on  : 09-29-2025
 * @last modified by  : Daniel Belini
**/
public without sharing class RemarketingRouter {

    public class Input {
        @InvocableVariable(required=true)
        public String conversationIdentifier;

        @InvocableVariable(label='Quantidade de mensagens a retornar' required=true)
        public Integer messageLimit;

        @InvocableVariable(label='Filtro de mensagens (business, enduser, all)' required=false)
        public String senderFilter; // default = all
    }

    public class MessageDetail {
        @InvocableVariable public String text;
        @InvocableVariable public String role;
        @InvocableVariable public String appType;
    }

    public class Output {
        @InvocableVariable public Boolean isRemarketing;
        @InvocableVariable public String lastMessage;
        @InvocableVariable public List<MessageDetail> messages;
        @InvocableVariable public List<String> messagesString; // mensagens como JSON
    }

    @InvocableMethod(label='Detect Remarketing in Conversation')
    public static List<Output> run(List<Input> inputs) {
        List<Output> results = new List<Output>();
        String logSummary = '';

        for (Input input : inputs) {
            HttpRequest req = new HttpRequest();
            String endpointUrl = 'callout:Salesforce_PRD/services/data/v64.0/connect/conversation/' +
                input.conversationIdentifier +
                '/entries?recordLimit=' + input.messageLimit +
                '&queryDirection=FromEnd';

            req.setEndpoint(endpointUrl);
            req.setMethod('GET');

            HttpResponse res = new Http().send(req);
            System.debug('🔎 Raw Response: ' + res.getBody());
            logSummary += '\n=== Conversa: ' + input.conversationIdentifier;

            Output out = new Output();
            out.messages = new List<MessageDetail>();
            out.messagesString = new List<String>();

            if (res.getStatusCode() == 200) {
                Map<String,Object> jsonMap = (Map<String,Object>)JSON.deserializeUntyped(res.getBody());
                List<Object> entries = (List<Object>)jsonMap.get('conversationEntries');
                System.debug('📌 Total de entradas recebidas: ' + entries.size());
                logSummary += '\nTotal de mensagens recebidas: ' + entries.size();

                Integer count = 0;
                for (Integer i = entries.size()-1; i >= 0 && count < input.messageLimit; i--) {
                    Map<String,Object> e = (Map<String,Object>)entries.get(i);
                    Map<String,Object> sender = (Map<String,Object>)e.get('sender');
                    String role = sender != null ? (String)sender.get('role') : null;
                    String appType = sender != null ? (String)sender.get('appType') : null;
                    String msg = (String)e.get('messageText');

                    System.debug('➡️ Mensagem analisada: ' + msg + ' | role=' + role + ' | appType=' + appType);

                    Boolean include = false;
                    if (input.senderFilter == null || input.senderFilter.toLowerCase() == 'all') {
                        include = true;
                    } else if (input.senderFilter.toLowerCase() == 'business' && role != null && role.toLowerCase() != 'enduser') {
                        include = true;
                    } else if (input.senderFilter.toLowerCase() == 'enduser' && role != null && role.toLowerCase() == 'enduser') {
                        include = true;
                    }

                    if (include && msg != null) {
                        MessageDetail md = new MessageDetail();
                        md.text = msg;
                        md.role = role;
                        md.appType = appType;
                        out.messages.add(md);
                        out.messagesString.add(JSON.serializePretty(md));

                        if (out.lastMessage == null) {
                            out.lastMessage = msg;
                        }
                        count++;
                    }
                }

                // regra de remarketing
                Boolean foundRemarketing = false;
                for (MessageDetail md : out.messages) {
                    if (md.text != null && md.text.contains('Gostaria de saber mais sobre as soluções')) {
                        foundRemarketing = true;
                        break;
                    }
                }
                out.isRemarketing = foundRemarketing;

                System.debug('✅ isRemarketing = ' + out.isRemarketing);
                System.debug('✅ lastMessage = ' + out.lastMessage);

                logSummary += '\nisRemarketing: ' + out.isRemarketing;
                logSummary += '\nlastMessage: ' + out.lastMessage;

            } else {
                System.debug('❌ Erro na chamada de conversa: ' + res.getStatusCode() + ' - ' + res.getBody());
                logSummary += '\nErro HTTP: ' + res.getStatusCode();
            }

            results.add(out);
        }

        // Envia resumo por email
        try {
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(new String[] { 'belinidaniel@gmail.com' });
            mail.setSubject('Resumo execução RemarketingRouter');
            mail.setPlainTextBody('Segue resumo do processamento:\n' + logSummary);
            Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
        } catch (Exception ex) {
            System.debug('⚠️ Falha ao enviar email: ' + ex.getMessage());
        }

        return results;
    }
}