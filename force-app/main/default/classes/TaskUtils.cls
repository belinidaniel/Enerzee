public with sharing class TaskUtils {
    //  Status
    public static String STATUS_OPEN         = 'Open';
    public static String STATUS_CONCLUIDO    = 'Completed';
    public static String STATUS_NAO_INICIADO = 'Not Started';

    //  Assunto
    public static String SUBJECT_DELEGAR_PROJETISTA                                          = 'DELEGAR PROJETISTA';
    public static String SUBJECT_INSERIR_ART                                                 = 'INSERIR ART';
    public static String SUBJECT_REALIZAR_PAGAMENTO_DA_ART                                   = 'REALIZAR PAGAMENTO DA ART';
    public static String SUBJECT_INSERIR_PROCURACAO_ASSINADA                                 = 'INSERIR PROCURAÇÃO ASSINADA';
    public static String SUBJECT_VERIFICAR_DOCUMENTOS                                        = 'VERIFICAR DOCUMENTOS';
    public static String SUBJECT_VERIFICAR_DOCUMENTACAO_COMERCIAL                            = 'VERIFICAR DOCUMENTAÇÃO COMERCIAL';
    public static String SUBJECT_VERIFICAR_VIABILIDADE_TECNICA                               = 'VERIFICAR VIABILIDADE TÉCNICA';
    public static String SUBJECT_SOLICITAR_VERIFICACAO_DE_PROJETO                            = 'SOLICITAR VERIFICAÇÃO DE PROJETO';
    public static String SUBJECT_ANEXAR_PROJETO_DE_CONCESSIONARIA                            = 'ANEXAR PROJETO DE CONCESSIONÁRIA';
    public static String SUBJECT_SOLICITAR_PROTOCOLO_DE_PROJETO                              = 'SOLICITAR PROTOCOLO DE PROJETO';
    public static String SUBJECT_PROTOCOLO_PROJETO_UFV                                       = 'PROTOCOLO PROJETO UFV';
    public static String SUBJECT_CONFIRMAR_PROTOCOLO_DAS_BENEFICIARIAS                       = 'CONFIRMAR PROTOCOLO DAS BENEFICIARIAS';
    public static String SUBJECT_APROVACAO_DO_PROJETO_UFV                                    = 'APROVAÇÃO DO PROJETO UFV';
    public static String SUBJECT_DELEGAR_GESTOR_DE_OBRAS                                     = 'DELEGAR GESTOR DE OBRAS';
    public static String SUBJECT_PASSAGEM_DE_BASTAO_KICK_OFF_INTERNO                         = 'PASSAGEM DE BASTÃO (Kick Off Interno)';
    public static String SUBJECT_KICK_OFF_COM_O_CLIENTE                                      = 'KICK OFF COM O CLIENTE';
    public static String SUBJECT_INSERIR_PEDIDO_KIT_WEG                                      = 'INSERIR PEDIDO KIT WEG';
    public static String SUBJECT_CONTRATAR_INTEGRADOR                                        = 'CONTRATAR INTEGRADOR';
    public static String SUBJECT_SOLICITAR_PAGAMENTO_DE_INTEGRADOR                           = 'SOLICITAR PAGAMENTO DE INTEGRADOR';
    public static String SUBJECT_ANEXAR_COMPROVANTE_DE_PAGAMENTO_DO_INTEGRADOR               = 'ANEXAR COMPROVANTE DE PAGAMENTO DO INTEGRADOR';
    public static String SUBJECT_ANEXAR_PROJETO_EXECUTIVO_E_LISTA_DE_MATERIAIS               = 'ANEXAR PROJETO EXECUTIVO E LISTA DE MATERIAIS';
    public static String SUBJECT_VALIDAR_LISTA_DE_MATERIAS                                   = 'VALIDAR LISTA DE MATERIAS';
    public static String SUBJECT_SOLICITAR_COMPRA_DE_MATERIAIS_COMPLEMENTARES                = 'SOLICITAR COMPRA DE MATERIAIS COMPLEMENTARES';
    public static String SUBJECT_RECEBIMENTO_DOS_MATERIAIS_COMPLEMENTARES                    = 'RECEBIMENTO DOS MATERIAIS COMPLEMENTARES';
    public static String SUBJECT_RECEBIMENTO_DO_KIT_WEG                                      = 'RECEBIMENTO DO KIT WEG';
    public static String SUBJECT_EXECUCAO_DA_OBRA                                            = 'EXECUÇÃO DA OBRA';
    public static String SUBJECT_SOLICITAR_DE_VISTORIA_TROCA_DE_MEDIDOR                      = 'SOLICITAR DE VISTORIA/TROCA DE MEDIDOR';
    public static String SUBJECT_START_USINA                                                 = 'START USINA';
    public static String SUBJECT_RELATORIO_FINAL_DE_OBRA_E_TERMO_CONCLUSAO                   = 'RELATÓRIO FINAL DE OBRA E TERMO CONCLUSÃO';
    public static String SUBJECT_SOLICITACAO_DE_VISTORIA_TROCA_DE_MEDIDOR                    = 'SOLICITAÇÃO DE VISTORIA/TROCA DE MEDIDOR';
    public static String SUBJECT_INSERIR_PEDIDO_WEG                                          = 'INSERIR PEDIDO WEG';
    public static String SUBJECT_RECEBIMENTO_DO_PEDIDO_WEG                                   = 'RECEBIMENTO DO PEDIDO WEG';
    public static String SUBJECT_ANEXAR_PROJETO_ELETRICO_EXECUTIVO_E_LISTA_DE_MATERIAIS      = 'ANEXAR PROJETO ELETRICO EXECUTIVO E LISTA DE MATERIAIS';
    public static String SUBJECT_VALIDAR_DA_LISTA_DE_MATERIAS                                = 'VALIDAR DA LISTA DE MATERIAS';
    public static String SUBJECT_SOLICITAR_COMPRA_DE_MATERIAIS                               = 'SOLICITAR COMPRA DE MATERIAIS';
    public static String SUBJECT_RECEBIMENTO_DOS_MATERIAIS                                   = 'RECEBIMENTO DOS MATERIAIS';
    public static String SUBJECT_TESTES_DE_OPERACAO                                          = 'TESTES DE OPERAÇÃO';
    public static String SUBJECT_RELATORIO_FINAL_DE_OBRA                                     = 'RELATÓRIO FINAL DE OBRA';
    public static String SUBJECT_SOLICITAR_DISPONIBILIDADE                                   = 'SOLICITAR DISPONIBILIDADE';
    public static String SUBJECT_APROVACAO_DA_DISPONIBILIDADE                                = 'APROVAÇÃO DA DISPONIBILIDADE';
    public static String SUBJECT_PROTOCOLAR_PROJETO                                          = 'PROTOCOLAR PROJETO';
    public static String SUBJECT_APROVACAO_DO_PROJETO                                        = 'APROVAÇÃO DO PROJETO';
    public static String SUBJECT_SOLICITAR_FISCALIZACAO                                      = 'SOLICITAR FISCALIZAÇÃO';
    public static String SUBJECT_SOLICITAR_CONTRATOS                                         = 'SOLICITAR CONTRATOS';
    public static String SUBJECT_SOLICITAR_LIGACAO                                           = 'SOLICITAR LIGAÇÃO';
    public static String SUBJECT_SOLICITAR_ESTUDOS_ELETRICOS                                 = 'SOLICITAR ESTUDOS ELETRICOS';
    public static String SUBJECT_PROTOCOLAR_PROJETO_ELETRICO                                 = 'PROTOCOLAR PROJETO ELETRICO';
    public static String SUBJECT_DEFINICAO_DE_CASO                                           = 'DEFINIÇÃO DE CASO';
    public static String SUBJECT_SOLICITAR_VISTORIA_DE_PADRONIZACAO                          = 'SOLICITAR VISTORIA DE PADRONIZAÇÃO';
    public static String SUBJECT_VERIFICAR_DOCUMENTOS_DO_CLIENTE                             = 'VERIFICAR DOCUMENTOS DO CLIENTE';
    public static String SUBJECT_SOLICITACAO_DE_PROTOCOLO_E_ANEXAR_DOCUMENTOS_CONCESSIONARIA = 'SOLICITAÇÃO DE PROTOCOLO E ANEXAR DOCUMENTOS CONCESSIONÁRIA';
    public static String SUBJECT_PROTOCOLO_PROJETO_ELETRICO                                  = 'PROTOCOLO PROJETO ELETRICO';
    public static String SUBJECT_APROVACAO_PROJETO_ELETRICO                                  = 'APROVAÇÃO PROJETO ELETRICO';


    //  Validação de Status
    public static Boolean isTaskOpen(Task task){
        return  task.Status.equalsIgnoreCase(STATUS_OPEN);
    }

    public static Boolean isTaskConcluded(Task task){
        return  task.Status.equalsIgnoreCase(STATUS_CONCLUIDO);
    }

    public static Boolean isTaskNotStarted(Task task){
        return  task.Status.equalsIgnoreCase(STATUS_NAO_INICIADO);
    }

    public static Boolean isTaskBeingConcluded(Task oldTask, Task newTask){
        return  !isTaskConcluded(oldTask) && isTaskConcluded(newTask);
    }


    //  Validação de Assunto
    public static Boolean isSubjectContratarIntegrador(Task task){
        return  task.Subject.equalsIgnoreCase(SUBJECT_CONTRATAR_INTEGRADOR);
    }

    public static Boolean isSubjectSolicitarCompraMateriais(Task task){
        return  task.Subject.equalsIgnoreCase(SUBJECT_SOLICITAR_COMPRA_DE_MATERIAIS);
    }
    
    public static Boolean isSubjectSolicitarCompraMateriaisComplementares(Task task){
        return  task.Subject.equalsIgnoreCase(SUBJECT_SOLICITAR_COMPRA_DE_MATERIAIS_COMPLEMENTARES);
    }
}
