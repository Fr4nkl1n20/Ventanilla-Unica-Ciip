/* ══════════════════════════════════════════════════════════════════════
   ██  LOS PASOS DE CADA TRÁMITE  ██
   ══════════════════════════════════════════════════════════════════════

   Lo lee ciip-ventanilla-unica-local.html para dibujar el detalle de un
   trámite cuando se pulsa su tarjeta.

   ─────────────────────────────────────────────────────────────────────
   POR QUÉ ESTÁ AQUÍ Y NO EN EL DICCIONARIO I18N
   ─────────────────────────────────────────────────────────────────────
   El diccionario del panel es un objeto en UNA sola línea de 57.000
   caracteres. Meterle 366 textos más lo dejaría imposible de editar a
   mano. Aquí cada trámite ocupa una línea legible y se corrige sin
   miedo.

   ─────────────────────────────────────────────────────────────────────
   CÓMO SE USA
   ─────────────────────────────────────────────────────────────────────
   Las claves c1…c15 son las mismas que ya usa el panel para el nombre
   de cada tarjeta (data-i18n="c1.name"), así que no hay una segunda
   numeración que mantener.

   Son CUATRO pasos por trámite, siempre. Dónde va cada uno NO se decide
   aquí: sale del estado de su tarjeta (data-st), para que el punto de
   avance y el distintivo de la tarjeta no puedan contradecirse.

       listo      → los cuatro hechos
       proceso    → dos hechos, el tercero en curso
       accion     → uno hecho, el segundo esperándote
       pendiente  → ninguno empezado

   ─────────────────────────────────────────────────────────────────────
   AVISO
   ─────────────────────────────────────────────────────────────────────
   Estos pasos son una RECONSTRUCCIÓN razonable de cada trámite, no una
   fuente oficial. Antes de enseñar el panel fuera del CIIP conviene que
   los revise quien tramite de verdad con cada organismo.
   ══════════════════════════════════════════════════════════════════════ */

window.CIIP_PASOS = {

  /* Título de la sección, y la etiqueta del paso en el que se está */
  titulo: {
    es: "El proceso", en: "The process", pt: "O processo",
    it: "Il processo", zh: "办理流程", ru: "Процесс"
  },
  aqui: {
    es: "Vas por aquí", en: "You are here", pt: "Está aqui",
    it: "Sei qui", zh: "当前进度", ru: "Вы здесь"
  },

  /* ═══════════════════════════════════════════════════════════════════
     LO QUE SIGUE ES DE LOS TRÁMITES QUE YA FUNCIONAN DE VERDAD
     ═══════════════════════════════════════════════════════════════════
     Las listas de arriba son decorado: describen cómo es el trámite ante
     el ente. Lo de aquí abajo describe el circuito del CIIP, que es lo
     único que la ventanilla puede saber de verdad, y sale de la base de
     datos. Un trámite usa uno u otro según esté activo en el catálogo.
     ═══════════════════════════════════════════════════════════════════ */

  /* Los cuatro estados por los que pasa una solicitud de verdad.
     {ente} se sustituye con el organismo que salga del catálogo. */
  estados: {
    es: ["Solicitud recibida por el CIIP", "Revisión de tus recaudos", "Presentada ante {ente}", "Resuelta"],
    en: ["Request received by CIIP", "Checking your documents", "Filed with {ente}", "Completed"],
    pt: ["Pedido recebido pelo CIIP", "Verificação dos seus documentos", "Apresentado ao {ente}", "Concluído"],
    it: ["Richiesta ricevuta dal CIIP", "Verifica dei tuoi documenti", "Presentata a {ente}", "Conclusa"],
    zh: ["CIIP 已收到申请", "核验您的材料", "已向 {ente} 提交", "已办结"],
    ru: ["Заявка получена CIIP", "Проверка ваших документов", "Подано в {ente}", "Завершено"]
  },

  /* Textos del formulario y de los avisos */
  ui: {
    es: {
      iniciar:      "Iniciar esta solicitud",
      tus_datos:    "Tus datos",
      recaudos:     "Recaudos",
      enviar:       "Enviar solicitud",
      enviando:     "Enviando…",
      guardado:     "Solicitud enviada",
      tu_solicitud: "Tu solicitud",
      enviada_el:   "Enviada el",
      adjuntos:     "Recaudos entregados",
      devuelta:     "Te la devolvimos: falta algo",
      falta:        "Rellena los campos marcados",
      sin_archivo:  "Elige el archivo",
      error:        "No se pudo enviar. Inténtalo otra vez.",
      reutilizado:  "ya estaba en tu expediente",
      f_tipodoc:    "Documento de identidad",
      f_numero:     "Número",
      f_nacimiento: "Fecha de nacimiento",
      f_direccion:  "Dirección fiscal en Venezuela",
      f_telefono:   "Teléfono",
      f_profesion:  "Profesión u oficio",
      d_identidad:  "Cédula o pasaporte",
      d_domicilio:  "Comprobante de domicilio",
      /* --- RIF de la empresa --- */
      f_razon:       "Razón social",
      f_registro:    "N.º de Registro Mercantil",
      f_constitucion:"Fecha de constitución",
      f_actividad:   "Actividad económica",
      f_capital:     "Capital social",
      d_acta:        "Acta constitutiva",
      d_rifpersonal: "Tu RIF personal",
      d_domemp:      "Domicilio fiscal de la empresa",
      /* --- Visa de inversionista (SAIME) --- */
      f_pasaporte:   "N.º de pasaporte",
      f_paisemisor:  "País emisor del pasaporte",
      f_vencepas:    "Vencimiento del pasaporte",
      f_consulado:   "Consulado donde tramitas",
      f_montoinv:    "Monto estimado de la inversión",
      f_motivo:      "En qué vas a invertir",
      d_pasaporte:   "Pasaporte vigente",
      d_foto:        "Fotografía tipo carnet",
      d_antecedentes:"Antecedentes penales apostillados",
      d_inversion:   "Constancia de la inversión"
    },
    en: {
      iniciar:      "Start this request",
      tus_datos:    "Your details",
      recaudos:     "Documents",
      enviar:       "Send request",
      enviando:     "Sending…",
      guardado:     "Request sent",
      tu_solicitud: "Your request",
      enviada_el:   "Sent on",
      adjuntos:     "Documents provided",
      devuelta:     "Sent back to you: something is missing",
      falta:        "Fill in the highlighted fields",
      sin_archivo:  "Choose the file",
      error:        "It could not be sent. Please try again.",
      reutilizado:  "already in your file",
      f_tipodoc:    "Identity document",
      f_numero:     "Number",
      f_nacimiento: "Date of birth",
      f_direccion:  "Tax address in Venezuela",
      f_telefono:   "Phone",
      f_profesion:  "Occupation",
      d_identidad:  "ID card or passport",
      d_domicilio:  "Proof of address",
      /* --- RIF de la empresa --- */
      f_razon:       "Company name",
      f_registro:    "Mercantile Registry number",
      f_constitucion:"Date of incorporation",
      f_actividad:   "Business activity",
      f_capital:     "Share capital",
      d_acta:        "Articles of incorporation",
      d_rifpersonal: "Your personal RIF",
      d_domemp:      "Company tax address proof",
      /* --- Investor visa (SAIME) --- */
      f_pasaporte:   "Passport number",
      f_paisemisor:  "Passport issuing country",
      f_vencepas:    "Passport expiry date",
      f_consulado:   "Consulate handling your application",
      f_montoinv:    "Estimated investment amount",
      f_motivo:      "What you will invest in",
      d_pasaporte:   "Valid passport",
      d_foto:        "Passport-size photograph",
      d_antecedentes:"Apostilled criminal record certificate",
      d_inversion:   "Proof of investment"
    },
    pt: {
      iniciar:      "Iniciar este pedido",
      tus_datos:    "Os seus dados",
      recaudos:     "Documentos",
      enviar:       "Enviar pedido",
      enviando:     "A enviar…",
      guardado:     "Pedido enviado",
      tu_solicitud: "O seu pedido",
      enviada_el:   "Enviado em",
      adjuntos:     "Documentos entregues",
      devuelta:     "Devolvido: falta alguma coisa",
      falta:        "Preencha os campos assinalados",
      sin_archivo:  "Escolha o ficheiro",
      error:        "Não foi possível enviar. Tente outra vez.",
      reutilizado:  "já estava no seu processo",
      f_tipodoc:    "Documento de identidade",
      f_numero:     "Número",
      f_nacimiento: "Data de nascimento",
      f_direccion:  "Morada fiscal na Venezuela",
      f_telefono:   "Telefone",
      f_profesion:  "Profissão",
      d_identidad:  "Cartão de cidadão ou passaporte",
      d_domicilio:  "Comprovativo de morada",
      /* --- RIF de la empresa --- */
      f_razon:       "Denominação social",
      f_registro:    "N.º do Registo Comercial",
      f_constitucion:"Data de constituição",
      f_actividad:   "Atividade económica",
      f_capital:     "Capital social",
      d_acta:        "Pacto social",
      d_rifpersonal: "O seu RIF pessoal",
      d_domemp:      "Comprovativo de morada fiscal da empresa",
      /* --- Visto de investidor (SAIME) --- */
      f_pasaporte:   "N.º do passaporte",
      f_paisemisor:  "País emissor do passaporte",
      f_vencepas:    "Validade do passaporte",
      f_consulado:   "Consulado onde tramita",
      f_montoinv:    "Valor estimado do investimento",
      f_motivo:      "Em que vai investir",
      d_pasaporte:   "Passaporte válido",
      d_foto:        "Fotografia tipo passe",
      d_antecedentes:"Registo criminal apostilado",
      d_inversion:   "Comprovativo do investimento"
    },
    it: {
      iniciar:      "Avvia questa richiesta",
      tus_datos:    "I tuoi dati",
      recaudos:     "Documenti",
      enviar:       "Invia richiesta",
      enviando:     "Invio in corso…",
      guardado:     "Richiesta inviata",
      tu_solicitud: "La tua richiesta",
      enviada_el:   "Inviata il",
      adjuntos:     "Documenti consegnati",
      devuelta:     "Te l'abbiamo rimandata: manca qualcosa",
      falta:        "Compila i campi evidenziati",
      sin_archivo:  "Scegli il file",
      error:        "Non è stato possibile inviarla. Riprova.",
      reutilizado:  "era già nella tua pratica",
      f_tipodoc:    "Documento d'identità",
      f_numero:     "Numero",
      f_nacimiento: "Data di nascita",
      f_direccion:  "Indirizzo fiscale in Venezuela",
      f_telefono:   "Telefono",
      f_profesion:  "Professione",
      d_identidad:  "Carta d'identità o passaporto",
      d_domicilio:  "Prova di residenza",
      /* --- RIF de la empresa --- */
      f_razon:       "Ragione sociale",
      f_registro:    "N. del Registro delle Imprese",
      f_constitucion:"Data di costituzione",
      f_actividad:   "Attività economica",
      f_capital:     "Capitale sociale",
      d_acta:        "Atto costitutivo",
      d_rifpersonal: "Il tuo RIF personale",
      d_domemp:      "Prova della sede fiscale",
      /* --- Visto per investitori (SAIME) --- */
      f_pasaporte:   "N. di passaporto",
      f_paisemisor:  "Paese di rilascio del passaporto",
      f_vencepas:    "Scadenza del passaporto",
      f_consulado:   "Consolato presso cui presenti la domanda",
      f_montoinv:    "Importo stimato dell'investimento",
      f_motivo:      "In cosa investirai",
      d_pasaporte:   "Passaporto valido",
      d_foto:        "Fototessera",
      d_antecedentes:"Certificato penale con apostille",
      d_inversion:   "Prova dell'investimento"
    },
    zh: {
      iniciar:      "开始办理",
      tus_datos:    "您的资料",
      recaudos:     "材料",
      enviar:       "提交申请",
      enviando:     "提交中…",
      guardado:     "申请已提交",
      tu_solicitud: "您的申请",
      enviada_el:   "提交于",
      adjuntos:     "已提交的材料",
      devuelta:     "已退回：还缺材料",
      falta:        "请填写标注的字段",
      sin_archivo:  "请选择文件",
      error:        "提交失败，请重试。",
      reutilizado:  "档案中已有",
      f_tipodoc:    "身份证件",
      f_numero:     "证件号码",
      f_nacimiento: "出生日期",
      f_direccion:  "在委内瑞拉的税务地址",
      f_telefono:   "电话",
      f_profesion:  "职业",
      d_identidad:  "身份证或护照",
      d_domicilio:  "住址证明",
      /* --- RIF de la empresa --- */
      f_razon:       "公司名称",
      f_registro:    "商业登记号",
      f_constitucion:"成立日期",
      f_actividad:   "经营范围",
      f_capital:     "注册资本",
      d_acta:        "公司章程",
      d_rifpersonal: "您的个人 RIF",
      d_domemp:      "公司税务地址证明",
      /* --- 投资者签证（SAIME） --- */
      f_pasaporte:   "护照号码",
      f_paisemisor:  "护照签发国",
      f_vencepas:    "护照有效期至",
      f_consulado:   "办理签证的领事馆",
      f_montoinv:    "预计投资金额",
      f_motivo:      "投资方向",
      d_pasaporte:   "有效护照",
      d_foto:        "证件照",
      d_antecedentes:"经认证的无犯罪记录证明",
      d_inversion:   "投资证明"
    },
    ru: {
      iniciar:      "Начать заявку",
      tus_datos:    "Ваши данные",
      recaudos:     "Документы",
      enviar:       "Отправить заявку",
      enviando:     "Отправка…",
      guardado:     "Заявка отправлена",
      tu_solicitud: "Ваша заявка",
      enviada_el:   "Отправлена",
      adjuntos:     "Переданные документы",
      devuelta:     "Возвращена: чего-то не хватает",
      falta:        "Заполните отмеченные поля",
      sin_archivo:  "Выберите файл",
      error:        "Не удалось отправить. Попробуйте ещё раз.",
      reutilizado:  "уже есть в вашем деле",
      f_tipodoc:    "Документ, удостоверяющий личность",
      f_numero:     "Номер",
      f_nacimiento: "Дата рождения",
      f_direccion:  "Налоговый адрес в Венесуэле",
      f_telefono:   "Телефон",
      f_profesion:  "Профессия",
      d_identidad:  "Удостоверение личности или паспорт",
      d_domicilio:  "Подтверждение адреса",
      /* --- RIF de la empresa --- */
      f_razon:       "Наименование компании",
      f_registro:    "Номер в торговом реестре",
      f_constitucion:"Дата учреждения",
      f_actividad:   "Вид деятельности",
      f_capital:     "Уставный капитал",
      d_acta:        "Учредительные документы",
      d_rifpersonal: "Ваш личный RIF",
      d_domemp:      "Подтверждение налогового адреса компании",
      /* --- Инвесторская виза (SAIME) --- */
      f_pasaporte:   "Номер паспорта",
      f_paisemisor:  "Страна выдачи паспорта",
      f_vencepas:    "Срок действия паспорта",
      f_consulado:   "Консульство, где оформляете",
      f_montoinv:    "Предполагаемая сумма инвестиций",
      f_motivo:      "Во что будете инвестировать",
      d_pasaporte:   "Действующий паспорт",
      d_foto:        "Фото на документы",
      d_antecedentes:"Справка о несудимости с апостилем",
      d_inversion:   "Подтверждение инвестиции"
    }
  },

  pasos: {

    es: {
      c1:  ["Solicitud en línea ante el SAIME", "Cita consular y consignación de recaudos", "Evaluación y aprobación", "Visa TR-I estampada en el pasaporte"],
      c2:  ["Registro del extranjero con la visa vigente", "Cita para captura biométrica", "Verificación de datos migratorios", "Entrega de la cédula de identidad"],
      c3:  ["Inscripción en el portal del SENIAT", "Carga de la cédula y del comprobante de domicilio", "Validación por la oficina fiscal", "Certificado de RIF disponible"],
      c4:  ["Traducción certificada de la licencia", "Solicitud de homologación ante el INTT", "Examen médico y de conocimiento", "Emisión de la licencia venezolana"],
      c5:  ["Reserva del nombre en el Registro Mercantil", "Firma del documento constitutivo", "Presentación y registro del expediente", "Publicación e inscripción definitiva"],
      c6:  ["Inscripción de la compañía en el SENIAT", "Consignación del acta constitutiva", "Asignación del número de RIF", "Certificado y clave del portal fiscal"],
      c7:  ["Elección del banco aliado", "Expediente de la empresa y de sus socios", "Cita presencial y firma de tarjetas", "Cuenta activa con banca en línea"],
      c8:  ["Búsqueda de antecedentes registrales", "Solicitud de registro ante el SAPI", "Publicación y plazo de oposición", "Concesión del certificado de marca"],
      c9:  ["Inscripción de la empresa en el IVSS", "Registro ante el INCES", "Afiliación al FAOV", "Alta de los trabajadores en los tres"],
      c10: ["Conformidad de uso del inmueble", "Solicitud de patente de industria y comercio", "Inspección municipal", "Licencia de funcionamiento otorgada"],
      c11: ["Registro como operador de comercio exterior", "Clasificación arancelaria de la mercancía", "Permisos sectoriales y certificado de origen", "Autorización de despacho aduanero"],
      c12: ["Análisis de laboratorio del producto", "Expediente técnico ante el INSAI", "Evaluación sanitaria y de calidad", "Registro sanitario otorgado"],
      c13: ["Inscripción en el sistema del RNC", "Carga de los estados financieros auditados", "Evaluación de capacidad legal y financiera", "Certificado de inscripción vigente"],
      c14: ["Solvencia laboral del Ministerio del Trabajo", "Solvencias del IVSS y del INCES", "Solvencia municipal de la alcaldía", "Expediente de solvencias al día"],
      c15: ["Perfil de inversión y sectores de interés", "Selección de activos y proyectos", "Acompañamiento del CIIP en la evaluación", "Carta de intención y cierre"]
    },

    en: {
      c1:  ["Online application to SAIME", "Consular appointment and paperwork", "Assessment and approval", "TR-I visa stamped in your passport"],
      c2:  ["Foreign national registration with a valid visa", "Appointment for biometric capture", "Verification of migration records", "Identity card issued"],
      c3:  ["Sign-up on the SENIAT portal", "Upload of ID and proof of address", "Validation by the tax office", "RIF certificate available"],
      c4:  ["Certified translation of your licence", "Conversion request to the INTT", "Medical and knowledge tests", "Venezuelan licence issued"],
      c5:  ["Company name reserved at the Mercantile Registry", "Signature of the articles of incorporation", "Filing and registration of the file", "Publication and final entry"],
      c6:  ["Company sign-up at SENIAT", "Filing of the articles of incorporation", "RIF number assigned", "Certificate and tax portal credentials"],
      c7:  ["Choice of partner bank", "File on the company and its shareholders", "In-person appointment and signatures", "Account live with online banking"],
      c8:  ["Search of prior registrations", "Registration request to SAPI", "Publication and opposition period", "Trademark certificate granted"],
      c9:  ["Company registration with the IVSS", "Registration with the INCES", "Enrolment with the FAOV", "Staff enrolled with all three"],
      c10: ["Land-use conformity for the premises", "Application for the municipal business licence", "Municipal inspection", "Operating licence granted"],
      c11: ["Registration as a foreign-trade operator", "Tariff classification of the goods", "Sector permits and certificate of origin", "Customs clearance authorised"],
      c12: ["Laboratory analysis of the product", "Technical file submitted to INSAI", "Health and quality assessment", "Health registration granted"],
      c13: ["Sign-up in the RNC system", "Upload of audited financial statements", "Review of legal and financial capacity", "Valid registration certificate"],
      c14: ["Labour clearance from the Ministry of Labour", "IVSS and INCES clearances", "Municipal clearance from the mayor’s office", "Clearance file up to date"],
      c15: ["Investment profile and sectors of interest", "Selection of assets and projects", "CIIP support during due diligence", "Letter of intent and closing"]
    },

    pt: {
      c1:  ["Solicitação em linha ao SAIME", "Entrevista consular e entrega de documentos", "Avaliação e aprovação", "Visto TR-I carimbado no passaporte"],
      c2:  ["Registo de estrangeiro com visto válido", "Marcação para recolha biométrica", "Verificação dos dados migratórios", "Entrega do cartão de identidade"],
      c3:  ["Inscrição no portal do SENIAT", "Carregamento do documento e do comprovativo de morada", "Validação pela repartição fiscal", "Certificado de RIF disponível"],
      c4:  ["Tradução certificada da carta de condução", "Pedido de equivalência ao INTT", "Exame médico e de conhecimentos", "Emissão da carta venezuelana"],
      c5:  ["Reserva do nome no Registo Comercial", "Assinatura do pacto social", "Apresentação e registo do processo", "Publicação e inscrição definitiva"],
      c6:  ["Inscrição da empresa no SENIAT", "Entrega do pacto social", "Atribuição do número de RIF", "Certificado e credenciais do portal fiscal"],
      c7:  ["Escolha do banco parceiro", "Processo da empresa e dos sócios", "Reunião presencial e assinaturas", "Conta ativa com banca em linha"],
      c8:  ["Pesquisa de antecedentes registais", "Pedido de registo ao SAPI", "Publicação e prazo de oposição", "Concessão do certificado de marca"],
      c9:  ["Inscrição da empresa no IVSS", "Registo no INCES", "Adesão ao FAOV", "Trabalhadores inscritos nos três"],
      c10: ["Conformidade de uso do imóvel", "Pedido de alvará de indústria e comércio", "Inspeção municipal", "Alvará de funcionamento concedido"],
      c11: ["Registo como operador de comércio externo", "Classificação pautal da mercadoria", "Licenças setoriais e certificado de origem", "Autorização de desalfandegamento"],
      c12: ["Análise laboratorial do produto", "Processo técnico junto do INSAI", "Avaliação sanitária e de qualidade", "Registo sanitário concedido"],
      c13: ["Inscrição no sistema do RNC", "Carregamento das demonstrações financeiras auditadas", "Avaliação da capacidade legal e financeira", "Certificado de inscrição válido"],
      c14: ["Certidão laboral do Ministério do Trabalho", "Certidões do IVSS e do INCES", "Certidão municipal da câmara", "Processo de certidões em dia"],
      c15: ["Perfil de investimento e setores de interesse", "Seleção de ativos e projetos", "Acompanhamento do CIIP na avaliação", "Carta de intenções e fecho"]
    },

    it: {
      c1:  ["Domanda online al SAIME", "Appuntamento consolare e consegna dei documenti", "Valutazione e approvazione", "Visto TR-I apposto sul passaporto"],
      c2:  ["Registrazione dello straniero con visto valido", "Appuntamento per il rilievo biometrico", "Verifica dei dati migratori", "Consegna della carta d’identità"],
      c3:  ["Iscrizione al portale del SENIAT", "Caricamento del documento e della prova di residenza", "Convalida da parte dell’ufficio fiscale", "Certificato RIF disponibile"],
      c4:  ["Traduzione giurata della patente", "Richiesta di conversione all’INTT", "Visita medica e prova teorica", "Rilascio della patente venezuelana"],
      c5:  ["Prenotazione del nome al Registro delle Imprese", "Firma dell’atto costitutivo", "Deposito e registrazione della pratica", "Pubblicazione e iscrizione definitiva"],
      c6:  ["Iscrizione della società al SENIAT", "Deposito dell’atto costitutivo", "Assegnazione del numero RIF", "Certificato e credenziali del portale fiscale"],
      c7:  ["Scelta della banca partner", "Fascicolo della società e dei soci", "Appuntamento in filiale e firme", "Conto attivo con banca online"],
      c8:  ["Ricerca di anteriorità", "Domanda di registrazione al SAPI", "Pubblicazione e termine di opposizione", "Rilascio del certificato di marchio"],
      c9:  ["Iscrizione dell’azienda all’IVSS", "Registrazione presso l’INCES", "Adesione al FAOV", "Dipendenti iscritti a tutti e tre"],
      c10: ["Conformità d’uso dell’immobile", "Domanda di licenza comunale", "Ispezione comunale", "Licenza di esercizio rilasciata"],
      c11: ["Registrazione come operatore del commercio estero", "Classificazione doganale della merce", "Permessi settoriali e certificato d’origine", "Autorizzazione allo sdoganamento"],
      c12: ["Analisi di laboratorio del prodotto", "Fascicolo tecnico all’INSAI", "Valutazione sanitaria e di qualità", "Registrazione sanitaria rilasciata"],
      c13: ["Iscrizione al sistema RNC", "Caricamento dei bilanci certificati", "Valutazione della capacità legale e finanziaria", "Certificato d’iscrizione valido"],
      c14: ["Certificazione del Ministero del Lavoro", "Certificazioni IVSS e INCES", "Certificazione comunale", "Fascicolo delle certificazioni aggiornato"],
      c15: ["Profilo d’investimento e settori d’interesse", "Selezione di asset e progetti", "Affiancamento del CIIP nella valutazione", "Lettera d’intenti e closing"]
    },

    zh: {
      c1:  ["向 SAIME 在线提交申请", "领事预约并递交材料", "审核与批准", "TR-I 签证已贴入护照"],
      c2:  ["持有效签证办理外国人登记", "预约采集生物特征", "核验出入境记录", "发放身份证"],
      c3:  ["在 SENIAT 门户注册", "上传身份证件与住址证明", "税务局审核", "RIF 证明可下载"],
      c4:  ["驾照的认证翻译", "向 INTT 提交换发申请", "体检与知识考试", "签发委内瑞拉驾照"],
      c5:  ["在商业登记处预留公司名称", "签署公司章程", "递交并登记文件", "公告与最终登记"],
      c6:  ["公司在 SENIAT 注册", "提交公司章程", "分配 RIF 号码", "证明与税务门户账号"],
      c7:  ["选择合作银行", "公司及股东资料", "到场预约与签字", "账户启用并开通网银"],
      c8:  ["在先商标检索", "向 SAPI 提交注册申请", "公告与异议期", "核发商标证书"],
      c9:  ["公司在 IVSS 登记", "在 INCES 登记", "加入 FAOV", "员工在三处完成登记"],
      c10: ["场所用途合规证明", "申请市政营业执照", "市政检查", "核发营业执照"],
      c11: ["注册为对外贸易经营者", "货物的税则归类", "行业许可与原产地证", "准予海关放行"],
      c12: ["产品实验室检测", "向 INSAI 提交技术档案", "卫生与质量评估", "核发卫生注册"],
      c13: ["在 RNC 系统登记", "上传经审计的财务报表", "法律与财务能力评估", "有效的登记证书"],
      c14: ["劳动部劳动清税证明", "IVSS 与 INCES 清税证明", "市政清税证明", "清税档案齐备"],
      c15: ["投资意向与关注行业", "筛选资产与项目", "CIIP 协助尽职调查", "意向书与交割"]
    },

    ru: {
      c1:  ["Онлайн-заявление в SAIME", "Запись в консульство и подача документов", "Рассмотрение и одобрение", "Виза TR-I вклеена в паспорт"],
      c2:  ["Регистрация иностранца с действующей визой", "Запись на снятие биометрии", "Проверка миграционных данных", "Выдача удостоверения личности"],
      c3:  ["Регистрация на портале SENIAT", "Загрузка удостоверения и подтверждения адреса", "Проверка налоговой инспекцией", "Свидетельство RIF доступно"],
      c4:  ["Заверенный перевод водительских прав", "Заявление на обмен в INTT", "Медосмотр и теоретический экзамен", "Выдача венесуэльских прав"],
      c5:  ["Резервирование названия в торговом реестре", "Подписание учредительного договора", "Подача и регистрация дела", "Публикация и окончательная запись"],
      c6:  ["Регистрация компании в SENIAT", "Подача учредительных документов", "Присвоение номера RIF", "Свидетельство и доступ к налоговому порталу"],
      c7:  ["Выбор банка-партнёра", "Досье компании и её участников", "Личная встреча и подписи", "Счёт открыт, подключён интернет-банк"],
      c8:  ["Проверка ранее зарегистрированных знаков", "Заявка на регистрацию в SAPI", "Публикация и срок для возражений", "Выдача свидетельства на знак"],
      c9:  ["Регистрация компании в IVSS", "Регистрация в INCES", "Присоединение к FAOV", "Работники зарегистрированы во всех трёх"],
      c10: ["Подтверждение назначения помещения", "Заявление на муниципальную лицензию", "Муниципальная проверка", "Лицензия на деятельность выдана"],
      c11: ["Регистрация как участника ВЭД", "Тарифная классификация товара", "Отраслевые разрешения и сертификат происхождения", "Разрешение на таможенное оформление"],
      c12: ["Лабораторный анализ продукции", "Технический пакет в INSAI", "Санитарная оценка и оценка качества", "Санитарная регистрация выдана"],
      c13: ["Регистрация в системе RNC", "Загрузка аудированной отчётности", "Оценка правоспособности и финансов", "Действующее свидетельство о регистрации"],
      c14: ["Справка Министерства труда", "Справки IVSS и INCES", "Муниципальная справка", "Пакет справок в порядке"],
      c15: ["Инвестиционный профиль и интересующие отрасли", "Отбор активов и проектов", "Сопровождение CIIP при оценке", "Письмо о намерениях и закрытие"]
    }

  }
};
