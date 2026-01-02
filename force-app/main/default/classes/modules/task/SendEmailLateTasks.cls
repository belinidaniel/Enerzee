public class SendEmailLateTasks {
    
    @InvocableMethod
    public static void sendEmail(List<User> Usuarios) {

        for(User usr : Usuarios){
            List<Messaging.SingleEmailMessage> messageList = new List<Messaging.SingleEmailMessage>();
            List<Task> tarefasAtrasadas = searchLateTasks(usr);
            Date Today = date.Today();
            DateTime currDate = DateTime.newInstance(Today.year(), Today.month(), Today.day());
            String todayDay = currDate.format('dd-MM-yyyy');
            String fullDate = currDate.format('MMMM dd, yyyy');

            if(tarefasAtrasadas.isEmpty()){
                continue;
            }

            String ManagerEmail = [SELECT Email FROM User WHERE Id =: usr.ManagerId LIMIT 1].Email;

            messageList.add(EmailUtils.createSingleEmailMessage(
                'Atividade Atrasadas - ' + todayDay,

                templateEmail(tarefasAtrasadas, usr, fullDate),

                new String[]{ usr.Email },

                new String[]{ ManagerEmail != null ? ManagerEmail : 'vitor.avancini@lab065.com', 'Kaique.mathias@lab065.com' }
            ));

            if(!Test.isRunningTest()){
                Messaging.SendEmailResult[] results = Messaging.sendEmail(messageList);
            }
        }

    }

    public static List<Task> searchLateTasks(User Usuario){
        List<Task> Tarefas = [
                SELECT Id, Subject, OwnerId, Owner.Name, WhatId, Priority, ActivityDate 
                FROM Task 
                WHERE Status = 'Open' AND ActivityDate < TODAY AND OwnerId =: Usuario.Id AND Subject LIKE '%Ligação de follow-up%'
            ];

        return Tarefas;
    }

    public static String templateEmail(List<Task> Tasks, User Usuario, String fullDate){
        String htmlBody = '<html><body>';

        htmlBody += '<div style="font-weight:400;word-spacing:normal;background-color:#f7f7f7;font-family:\'Source Sans Pro\',sans-serif"> ';
        htmlBody += '    <div style="font-weight:400;background-color:#f7f7f7;font-family:\'Source Sans Pro\',sans-serif" lang="und" dir="auto"> ';
        htmlBody += '        <div style="font-weight:400;margin:0px auto;max-width:600px;font-family:\'Source Sans Pro\',sans-serif"> ';
        htmlBody += '            <table align="center" border="0" cellpadding="0" cellspacing="0" role="presentation" style="font-weight:400;width:100%;font-family:\'Source Sans Pro\',sans-serif" width="100%"> ';
        htmlBody += '                <tbody style="font-weight:400;font-family:\'Source Sans Pro\',sans-serif"> ';
        htmlBody += '                    <tr style="font-weight:400;font-family:\'Source Sans Pro\',sans-serif"> ';
        htmlBody += '                        <td style="font-weight:400;direction:ltr;font-size:0px;padding:0 4px;text-align:center;font-family:\'Source Sans Pro\',sans-serif" align="center"> ';
        htmlBody += ' ';
        htmlBody += '                            <div style="font-weight:400;margin:0px auto;max-width:592px;font-family:\'Source Sans Pro\',sans-serif"> ';
        htmlBody += '                                <table align="center" border="0" cellpadding="0" cellspacing="0" role="presentation" style="font-weight:400;width:100%;font-family:\'Source Sans Pro\',sans-serif" width="100%"> ';
        htmlBody += '                                    <tbody style="font-weight:400;font-family:\'Source Sans Pro\',sans-serif"> ';
        htmlBody += '                                        <tr style="font-weight:400;font-family:\'Source Sans Pro\',sans-serif"> ';
        htmlBody += '                                            <td style="font-weight:400;direction:ltr;font-size:0px;padding:40px 0 0 0;text-align:center;font-family:\'Source Sans Pro\',sans-serif" align="center"> ';
        htmlBody += '                                                <div class="m_4882083532274502986mj-column-per-100" style="font-weight:400;font-size:0px;text-align:left;direction:ltr;display:inline-block;vertical-align:top;width:100%;font-family:\'Source Sans Pro\',sans-serif"> ';
        htmlBody += '                                                    <table border="0" cellpadding="0" cellspacing="0" role="presentation" style="font-weight:400;vertical-align:top;font-family:\'Source Sans Pro\',sans-serif" width="100%" valign="top"> ';
        htmlBody += '                                                        <tbody style="font-weight:400;font-family:\'Source Sans Pro\',sans-serif"> ';
        htmlBody += '                                                            <tr style="font-weight:400;font-family:\'Source Sans Pro\',sans-serif"> ';
        htmlBody += '                                                                <td align="center" style="font-weight:400;font-size:0px;padding:0;word-break:break-word;font-family:\'Source Sans Pro\',sans-serif"> ';
        htmlBody += '                                                                    <table border="0" cellpadding="0" cellspacing="0" role="presentation" style="font-weight:400;border-collapse:collapse;border-spacing:0px;font-family:\'Source Sans Pro\',sans-serif"> ';
        htmlBody += '                                                                        <tbody style="font-weight:400;font-family:\'Source Sans Pro\',sans-serif"> ';
        htmlBody += '                                                                            <tr style="font-weight:400;font-family:\'Source Sans Pro\',sans-serif"> ';
        htmlBody += '                                                                                <td class="pad" style="width:100%;padding-right:0;padding-left:0"> ';
        htmlBody += '                                                                                    <div align="center" class="alignment" style="line-height:10px"> ';
        htmlBody += '                                                                                        <div style="max-width:180px"> ';
        htmlBody += '                                                                                            <img height="auto" src="https://enerzee.com.br/uploads/config_cliente/Enerzee_logo%20%281%29.png" style="display:block;height:auto;border:0;width:100%" width="180" /> ';
        htmlBody += '                                                                                        </div> ';
        htmlBody += '                                                                                    </div> ';
        htmlBody += '                                                                                </td> ';
        htmlBody += '                                                                            </tr> ';
        htmlBody += '                                                                        </tbody> ';
        htmlBody += '                                                                    </table> ';
        htmlBody += '                                                                </td> ';
        htmlBody += '                                                            </tr> ';
        htmlBody += '                                                        </tbody> ';
        htmlBody += '                                                    </table> ';
        htmlBody += '                                                </div> ';
        htmlBody += '                                            </td> ';
        htmlBody += '                                        </tr> ';
        htmlBody += '                                    </tbody> ';
        htmlBody += '                                </table> ';
        htmlBody += '                            </div> ';
        htmlBody += ' ';
        htmlBody += '                            <div style="font-weight:400;margin:0px auto;max-width:592px;font-family:\'Source Sans Pro\',sans-serif"> ';
        htmlBody += '                                <table align="center" border="0" cellpadding="0" cellspacing="0" role="presentation" style="font-weight:400;width:100%;font-family:\'Source Sans Pro\',sans-serif" width="100%"> ';
        htmlBody += '                                    <tbody style="font-weight:400;font-family:\'Source Sans Pro\',sans-serif"> ';
        htmlBody += '                                        <tr style="font-weight:400;font-family:\'Source Sans Pro\',sans-serif"> ';
        htmlBody += '                                            <td style="font-weight:400;direction:ltr;font-size:0px;padding:0 0 24px 0;text-align:center;font-family:\'Source Sans Pro\',sans-serif" align="center"> ';
        htmlBody += '                                                <div class="m_4882083532274502986mj-column-per-100" style="font-weight:400;font-size:0px;text-align:left;direction:ltr;display:inline-block;vertical-align:top;width:100%;font-family:\'Source Sans Pro\',sans-serif"> ';
        htmlBody += '                                                    <table border="0" cellpadding="0" cellspacing="0" role="presentation" style="font-weight:400;vertical-align:top;font-family:\'Source Sans Pro\',sans-serif" width="100%" valign="top"> ';
        htmlBody += '                                                        <tbody style="font-weight:400;font-family:\'Source Sans Pro\',sans-serif"> ';
        htmlBody += '                                                            <tr style="font-weight:400;font-family:\'Source Sans Pro\',sans-serif"> ';
        htmlBody += '                                                                <td align="center" style="font-weight:400;font-size:0px;padding:24px 0 0 0;word-break:break-word;font-family:\'Source Sans Pro\',sans-serif"> ';
        htmlBody += '                                                                    <div style="font-weight:400;font-size:23px;line-height:28px;text-align:center;color:#404346;font-family:\'Source Sans Pro\',sans-serif"> ';
        htmlBody += '                                                                        Olá, '+Usuario.Name+'! ';
        htmlBody += '                                                                    </div> ';
        htmlBody += '                                                                </td> ';
        htmlBody += '                                                            </tr> ';
        htmlBody += ' ';
        htmlBody += '                                                            <tr style="font-weight:400;font-family:\'Source Sans Pro\',sans-serif"> ';
        htmlBody += '                                                                <td align="center" style="font-weight:400;font-size:0px;padding:4px 0 0 0;word-break:break-word;font-family:\'Source Sans Pro\',sans-serif"> ';
        htmlBody += '                                                                    <div style="font-weight:400;font-size:15px;line-height:20px;text-align:center;color:#404346;font-family:\'Source Sans Pro\',sans-serif"> ';
        htmlBody += '                                                                        Esta é sua atualização diária de atividades atrasadas.';
        htmlBody += '                                                                    </div> ';
        htmlBody += '                                                                </td> ';
        htmlBody += '                                                            </tr> ';
        htmlBody += '                                                        </tbody> ';
        htmlBody += '                                                    </table> ';
        htmlBody += '                                                </div> ';
        htmlBody += '                                            </td> ';
        htmlBody += '                                        </tr> ';
        htmlBody += '                                    </tbody> ';
        htmlBody += '                                </table> ';
        htmlBody += '                            </div> ';
        htmlBody += ' ';
        htmlBody += '                            <div style="font-weight: 400; background: #ffffff; background-color: #ffffff; margin: 0px auto; max-width: 592px; font-family: \'Source Sans Pro\', sans-serif;"> ';
        htmlBody += '                                <table align="center" border="0" cellpadding="0" cellspacing="0" role="presentation" style="font-weight: 400; background: #ffffff; background-color: #ffffff; width: 100%; font-family: \'Source Sans Pro\', sans-serif;" width="100%" bgcolor="#ffffff"> ';
        htmlBody += '                                    <tbody style="font-weight: 400; font-family: \'Source Sans Pro\', sans-serif;"> ';
        htmlBody += '                                        <tr style="font-weight: 400; font-family: \'Source Sans Pro\', sans-serif;"> ';
        htmlBody += '                                            <td style="font-weight: 400; border-bottom: 1px solid #eeeeee; direction: ltr; font-size: 0px; padding: 12px 20px; text-align: center; font-family: \'Source Sans Pro\', sans-serif;" align="center"> ';
        htmlBody += '                                                <div class="m_4882083532274502986mj-column-per-100" style="font-weight: 400; font-size: 0px; text-align: left; direction: ltr; display: inline-block; vertical-align: top; width: 100%; font-family: \'Source Sans Pro\', sans-serif;"> ';
        htmlBody += '                                                    <table border="0" cellpadding="0" cellspacing="0" role="presentation" style="font-weight: 400; vertical-align: top; font-family: \'Source Sans Pro\', sans-serif;" width="100%" valign="top"> ';
        htmlBody += '                                                        <tbody style="font-weight: 400; font-family: \'Source Sans Pro\', sans-serif;"> ';
        htmlBody += '                                                            <tr style="font-weight: 400; font-family: \'Source Sans Pro\', sans-serif;"> ';
        htmlBody += '                                                                <td align="left" style="font-weight: 400; font-size: 0px; padding: 0; word-break: break-word; font-family: \'Source Sans Pro\', sans-serif;"> ';
        htmlBody += '                                                                    <div style="font-size: 15px; font-weight: 600; line-height: 20px; text-align: left; color: #747678; font-family: \'Source Sans Pro\', sans-serif;"> ';
        htmlBody += '                                                                        Atividades Atrasadas ';
        htmlBody += '                                                                    </div> ';
        htmlBody += '                                                                </td> ';
        htmlBody += '                                                            </tr> ';
        htmlBody += '                                                        </tbody> ';
        htmlBody += '                                                    </table> ';
        htmlBody += '                                                </div> ';
        htmlBody += '                                            </td> ';
        htmlBody += '                                        </tr> ';
        htmlBody += '                                    </tbody> ';
        htmlBody += '                                </table> ';
        htmlBody += '                            </div> ';
        htmlBody += ' ';
        htmlBody += '                            <div style="font-weight: 400; background: #ffffff; background-color: #ffffff; margin: 0px auto; max-width: 592px; font-family: \'Source Sans Pro\', sans-serif;"> ';
        htmlBody += '                                <table align="center" border="0" cellpadding="0" cellspacing="0" role="presentation" style="font-weight: 400; background: #ffffff; background-color: #ffffff; width: 100%; font-family: \'Source Sans Pro\', sans-serif;" width="100%" bgcolor="#ffffff"> ';
        htmlBody += '                                    <tbody style="font-weight: 400; font-family: \'Source Sans Pro\', sans-serif;"> ';
        htmlBody += '                                        <tr style="font-weight: 400; font-family: \'Source Sans Pro\', sans-serif;"> ';
        htmlBody += '                                            <td style="font-weight: 400; direction: ltr; font-size: 0px; padding: 20px 20px 0 20px; text-align: center; font-family: \'Source Sans Pro\', sans-serif;" align="center"> ';
        htmlBody += '                                                <div class="m_4882083532274502986mj-column-per-100" style="font-weight: 400; font-size: 0px; text-align: left; direction: ltr; display: inline-block; vertical-align: top; width: 100%; font-family: \'Source Sans Pro\', sans-serif;"> ';
        htmlBody += '                                                    <table border="0" cellpadding="0" cellspacing="0" role="presentation" style="font-weight: 400; vertical-align: top; font-family: \'Source Sans Pro\', sans-serif;" width="100%" valign="top"> ';
        htmlBody += '                                                        <tbody style="font-weight: 400; font-family: \'Source Sans Pro\', sans-serif;"> ';
        htmlBody += '                                                            <tr style="font-weight: 400; font-family: \'Source Sans Pro\', sans-serif;"> ';
        htmlBody += '                                                                <td align="left" style="font-weight: 400; font-size: 0px; padding: 0; word-break: break-word; font-family: \'Source Sans Pro\', sans-serif;"> ';
        htmlBody += '                                                                    <div style="font-weight: 400; font-size: 13px; line-height: 16px; text-align: left; text-transform: uppercase; color: #747678; font-family: \'Source Sans Pro\', sans-serif;"> ';
        htmlBody += '                                                                        HOJE, ' + fullDate + ' ';
        htmlBody += '                                                                    </div> ';
        htmlBody += '                                                                </td> ';
        htmlBody += '                                                            </tr> ';
        htmlBody += '                                                        </tbody> ';
        htmlBody += '                                                    </table> ';
        htmlBody += '                                                </div> ';
        htmlBody += '                                            </td> ';
        htmlBody += '                                        </tr> ';
        htmlBody += '                                    </tbody> ';
        htmlBody += '                                </table> ';
        htmlBody += '                            </div> ';
        htmlBody += ' ';

        for (Task Tarefas : Tasks) {
            Date Adt = Tarefas.ActivityDate;
            DateTime AdtFormat = DateTime.newInstance(Adt.year(), Adt.month(), Adt.day());
            String ActivityDate = AdtFormat.format('dd-MM-yyyy');

            htmlBody += ' <div style="font-weight:400;background:#ffffff;background-color:#ffffff;margin:0px auto;max-width:592px;font-family:\'Source Sans Pro\',sans-serif"> ';
            htmlBody += '     <table align="center" border="0" cellpadding="0" cellspacing="0" role="presentation" style="font-weight:400;background:#ffffff;background-color:#ffffff;width:100%;font-family:\'Source Sans Pro\',sans-serif" width="100%" bgcolor="#ffffff"> ';
            htmlBody += '         <tbody style="font-weight:400;font-family:\'Source Sans Pro\',sans-serif"> ';
            htmlBody += '             <tr style="font-weight:400;font-family:\'Source Sans Pro\',sans-serif"> ';
            htmlBody += '                 <td style="font-weight:400;direction:ltr;font-size:0px;padding:20px 20px 0 20px;text-align:center;font-family:\'Source Sans Pro\',sans-serif" align="center"> ';
            htmlBody += '                     <span style="font-weight:400;font-family:\'Source Sans Pro\',sans-serif"> ';
            htmlBody += '                         <table border="0" style="font-weight:400;font-family:\'Source Sans Pro\',sans-serif"> ';
            htmlBody += '                             <tbody style="font-weight:400;font-family:\'Source Sans Pro\',sans-serif"> ';
            htmlBody += '                                 <tr style="font-weight:400;font-family:\'Source Sans Pro\',sans-serif"> ';
            htmlBody += '                                     <td style="font-weight:400;vertical-align:top;font-family:\'Source Sans Pro\',sans-serif" valign="top"> ';
            htmlBody += '                                         <div style="font-weight:400;padding-top:2px;font-family:\'Source Sans Pro\',sans-serif"> ';
            htmlBody += '                                             <div style="font-weight:400;width:44px;height:44px;background-image:url(\'https://ci3.googleusercontent.com/meips/ADKq_NZoueFMLVG2UZdAnfbx4xdhvuQKiKa-iU6Vm6i4zoQ5Qp4b0h3k5nmQ2_oEU-PnaySKr9eoaniihwtBKTbjPDB0UV1i5JpggP2VyuHXYVJH9BUIJHSCxL-b2aNRCMm3m8_hbWU=s0-d-e1-ft#https://cdn.pdx-2.pipedriveassets.com/proactive-email/images/background@3x.png\');background-size:cover;font-family:\'Source Sans Pro\',sans-serif"> ';
            htmlBody += '                                                 <img style="font-weight:400;padding:9px;width:24px;height:24px;font-family:\'Source Sans Pro\',sans-serif" src="https://ci3.googleusercontent.com/meips/ADKq_NasOEawynfzi03-XDz8pOdBDAlRoGO_YPVT_K0FGFHlWwx3JF6AxTrKKdw9o3cBqF8rKL6U-egXQuCc-bN_NvsLz3hJceAlRInWJyS-5OcURVh2QaGD4ekHqcqY9kNc8LozBBYATIXb6g=s0-d-e1-ft#https://cdn.pdx-2.pipedriveassets.com/proactive-email/activity-icons/ac-task@3x.png" width="24" height="24" class="CToWUd" data-bit="iit"> ';
            htmlBody += '                                             </div> ';
            htmlBody += '                                         </div> ';
            htmlBody += '                                     </td> ';
            htmlBody += '                                     <td width="100%" style="font-weight:400;font-family:\'Source Sans Pro\',sans-serif"> ';
            htmlBody += '                                         <div style="font-weight:400;padding-left:16px;font-family:\'Source Sans Pro\',sans-serif"> ';
            htmlBody += '                                             <div style="font-weight:400;text-align:left;font-size:15px;line-height:20px;color:#26292c;font-family:\'Source Sans Pro\',sans-serif"></div> ';
            htmlBody += '                                             <div style="padding-top:2px;text-align:left;font-size:18px;font-weight:600;line-height:24px;font-family:\'Source Sans Pro\',sans-serif"> ';
            htmlBody += '                                                 <a href="https://enrz.lightning.force.com/lightning/r/Task/' + Tarefas.Id + '/view" style="font-weight: 400; font-family: \'Source Sans Pro\', sans-serif; text-decoration: none; color: #26292c;" target="_blank"> ';
            htmlBody += '                                                      '+ Tarefas.Subject +' ';
            htmlBody += '                                                 </a> ';
            htmlBody += '                                             </div> ';
            htmlBody += '                                             <div style="font-weight:400;padding-top:2px;text-align:left;font-size:15px;line-height:20px;text-decoration:none;color:#26292c;font-family:\'Source Sans Pro\',sans-serif" class="m_-7948257578969283442parties-links"> ';
            htmlBody += '                                                 '+ Tarefas.Owner.Name + ' · ' + Tarefas.Priority + ' · <span style="color:#BE0820;">' + ActivityDate + '</span> ';
            htmlBody += '                                             </div> ';
            htmlBody += '                                             <div style="font-weight:400;padding-top:2px;text-align:left;font-size:15px;line-height:20px;color:#747678;font-family:\'Source Sans Pro\',sans-serif"></div> ';
            htmlBody += '                                         </div> ';
            htmlBody += '                                     </td> ';
            htmlBody += '                                 </tr> ';
            htmlBody += '                             </tbody> ';
            htmlBody += '                         </table> ';
            htmlBody += '                     </span> ';
            htmlBody += '                 </td> ';
            htmlBody += '             </tr> ';
            htmlBody += '         </tbody> ';
            htmlBody += '     </table> ';
            htmlBody += ' </div> ';
        }

        htmlBody += ' ';
        htmlBody += '                            <div style="font-weight:400;background:#ffffff;background-color:#ffffff;margin:0px auto;max-width:592px;font-family:\'Source Sans Pro\',sans-serif"> ';
        htmlBody += '                                <table align="center" border="0" cellpadding="0" cellspacing="0" role="presentation" style="font-weight:400;background:#ffffff;background-color:#ffffff;width:100%;font-family:\'Source Sans Pro\',sans-serif" width="100%" bgcolor="#ffffff"> ';
        htmlBody += '                                    <tbody style="font-weight:400;font-family:\'Source Sans Pro\',sans-serif"> ';
        htmlBody += '                                        <tr style="font-weight:400;font-family:\'Source Sans Pro\',sans-serif"> ';
        htmlBody += '                                            <td style="font-weight:400;direction:ltr;font-size:0px;padding:20px 0 0 0;text-align:center;font-family:\'Source Sans Pro\',sans-serif" align="center"></td> ';
        htmlBody += '                                        </tr> ';
        htmlBody += '                                    </tbody> ';
        htmlBody += '                                </table> ';
        htmlBody += '                            </div> ';
        htmlBody += ' ';                        
        htmlBody += '                            <div style="font-weight:400;margin:0px auto;max-width:592px;font-family:\'Source Sans Pro\',sans-serif"> ';
        htmlBody += '                                <table align="center" border="0" cellpadding="0" cellspacing="0" role="presentation" style="font-weight:400;width:100%;font-family:\'Source Sans Pro\',sans-serif" width="100%"> ';
        htmlBody += '                                    <tbody style="font-weight:400;font-family:\'Source Sans Pro\',sans-serif"> ';
        htmlBody += '                                        <tr style="font-weight:400;font-family:\'Source Sans Pro\',sans-serif"> ';
        htmlBody += '                                            <td style="font-weight:400;direction:ltr;font-size:0px;padding:8px 0 0 0;text-align:center;font-family:\'Source Sans Pro\',sans-serif" align="center"></td> ';
        htmlBody += '                                        </tr> ';
        htmlBody += '                                    </tbody> ';
        htmlBody += '                                </table> ';
        htmlBody += '                            </div> ';                        
        htmlBody += ' ';
        htmlBody += '                            <div style="font-weight:400;margin:0px auto;max-width:592px;font-family:\'Source Sans Pro\',sans-serif"> ';
        htmlBody += '                                <table align="center" border="0" cellpadding="0" cellspacing="0" role="presentation" style="font-weight:400;width:100%;font-family:\'Source Sans Pro\',sans-serif" width="100%"> ';
        htmlBody += '                                    <tbody style="font-weight:400;font-family:\'Source Sans Pro\',sans-serif"> ';
        htmlBody += '                                        <tr style="font-weight:400;font-family:\'Source Sans Pro\',sans-serif"> ';
        htmlBody += '                                            <td style="font-weight:400;direction:ltr;font-size:0px;padding:32px 0 0 0;text-align:center;font-family:\'Source Sans Pro\',sans-serif" align="center"> ';
        htmlBody += '                                                <div class="m_4882083532274502986mj-column-per-100" style="font-weight:400;font-size:0px;text-align:left;direction:ltr;display:inline-block;vertical-align:top;width:100%;font-family:\'Source Sans Pro\',sans-serif"> ';
        htmlBody += '                                                    <table border="0" cellpadding="0" cellspacing="0" role="presentation" style="font-weight:400;vertical-align:top;font-family:\'Source Sans Pro\',sans-serif" width="100%" valign="top"> ';
        htmlBody += '                                                        <tbody style="font-weight:400;font-family:\'Source Sans Pro\',sans-serif"> ';
        htmlBody += '                                                            <tr style="font-weight:400;font-family:\'Source Sans Pro\',sans-serif"> ';
        htmlBody += '                                                                <td align="center" style="font-weight:400;font-size:0px;padding:0;word-break:break-word;font-family:\'Source Sans Pro\',sans-serif"> ';
        htmlBody += '                                                                    <table border="0" cellpadding="0" cellspacing="0" role="presentation" style="font-weight:400;border-collapse:separate;line-height:100%;font-family:\'Source Sans Pro\',sans-serif"> ';
        htmlBody += '                                                                        <tbody style="font-weight:400;font-family:\'Source Sans Pro\',sans-serif"> ';
        htmlBody += '                                                                            <tr style="font-weight:400;font-family:\'Source Sans Pro\',sans-serif"> ';
        htmlBody += '                                                                                <td align="center" bgcolor="#08a742" role="presentation" style="font-weight:400;border:none;border-radius:3px;background:#08a742;font-family:\'Source Sans Pro\',sans-serif" valign="middle"> ';
        htmlBody += '                                                                                    <a href="https://enrz.lightning.force.com/lightning/o/Task/list?filterName=Todas_as_Tarefas_em_aberto_do_meu_time" style="display:inline-block;background:#08a742;color:#ffffff;font-size:18px;font-weight:600;line-height:24px;margin:0;text-decoration:none;text-transform:none;padding:12px 25px;border-radius:3px;font-family:\'Source Sans Pro\',sans-serif" target="_blank"> ';
        htmlBody += '                                                                                        Ver minhas <span class="il"> Tarefas </span> ';
        htmlBody += '                                                                                    </a> ';
        htmlBody += '                                                                                </td> ';
        htmlBody += '                                                                            </tr> ';
        htmlBody += '                                                                        </tbody> ';
        htmlBody += '                                                                    </table> ';
        htmlBody += '                                                                </td> ';
        htmlBody += '                                                            </tr> ';
        htmlBody += '                                                        </tbody> ';
        htmlBody += '                                                    </table> ';
        htmlBody += '                                                </div> ';
        htmlBody += '                                            </td> ';
        htmlBody += '                                        </tr> ';
        htmlBody += '                                    </tbody> ';
        htmlBody += '                                </table> ';
        htmlBody += '                            </div> ';
        htmlBody += ' ';
        htmlBody += '                            <div style="font-weight:400;margin:0px auto;max-width:592px;font-family:\'Source Sans Pro\',sans-serif"> ';
        htmlBody += '                                <table align="center" border="0" cellpadding="0" cellspacing="0" role="presentation" style="font-weight:400;width:100%;font-family:\'Source Sans Pro\',sans-serif" width="100%"> ';
        htmlBody += '                                    <tbody style="font-weight:400;font-family:\'Source Sans Pro\',sans-serif"> ';
        htmlBody += '                                        <tr style="font-weight:400;font-family:\'Source Sans Pro\',sans-serif"> ';
        htmlBody += '                                            <td style="font-weight:400;direction:ltr;font-size:0px;padding:80px 0 0 0;text-align:center;font-family:\'Source Sans Pro\',sans-serif" align="center"> ';
        htmlBody += '                                            </td> ';
        htmlBody += '                                        </tr> ';
        htmlBody += '                                    </tbody> ';
        htmlBody += '                                </table> ';
        htmlBody += '                            </div> ';
        htmlBody += ' ';
        htmlBody += '                        </td> ';
        htmlBody += '                    </tr> ';
        htmlBody += '                </tbody> ';
        htmlBody += '            </table> ';
        htmlBody += '        </div> ';
        htmlBody += '    </div> ';
        htmlBody += '</div> ';
        htmlBody += '</body></html>';

        return htmlBody;

    }

}