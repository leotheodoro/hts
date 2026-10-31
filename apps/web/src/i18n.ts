// Site copy in pt-BR and English. Voice of the brand: short imperative lines, no exclamation, no emoji,
// buttons start with a verb (docs/design/design-system.md).

export type Lang = "pt" | "en";

export const CONTACT_EMAIL = "contact@hardtosubmit.com";

/** Where each page lives in each language. The privacy URLs go to Garmin and never change (#159). */
export const routes = {
  home: { pt: "/", en: "/en/" },
  privacy: { pt: "/privacidade", en: "/privacy" },
  support: { pt: "/suporte", en: "/en/support" },
} as const;

export type Page = keyof typeof routes;

export const copy = {
  pt: {
    htmlLang: "pt-BR",
    description:
      "App de iPhone para a preparação física do jiu-jitsu. Registre série por série; cada série vira XP, nível, patente e atributos.",
    nav: { privacy: "Privacidade", support: "Suporte", switchLabel: "English" },
    soon: "Em breve na App Store",
    hero: {
      image: "/screens/home.png",
      imageAlt: "Tela inicial com patente, XP, a Batalha e o treino em andamento",
      title: ["Treine.", "Não bata."],
      lead: "Preparação física para jiu-jitsu, série por série. Cada série concluída vira XP, nível, patente e atributos.",
    },
    how: {
      label: "Como funciona",
      items: [
        {
          title: "Temporadas e arcos",
          body: "Organize o ano em temporadas. Cada arco tem seus treinos e semanas e libera o próximo quando termina. A Manutenção fica sempre à mão.",
        },
        {
          title: "Treino ativo",
          body: "Carga e repetições de cada série, o que você fez da última vez e o timer de descanso com aviso. Rápido antes de ser bonito.",
        },
        {
          title: "Patentes",
          body: "Cada série dá XP. O XP sobe o nível, e o nível sobe a patente: de Recruta a Comandante.",
        },
        {
          title: "Atributos",
          body: "Cada bloco do treino alimenta os seus: força, explosão, gás, core e mobilidade. Veja onde você está forte e onde falta.",
        },
      ],
    },
    ranks: {
      label: "Patentes",
      list: ["Recruta", "Soldado", "Cabo", "Sargento", "Tenente", "Comandante"],
    },
    attributes: {
      label: "Atributos",
      list: [
        ["FOR", "Força"],
        ["EXP", "Explosão"],
        ["GÁS", "Resistência"],
        ["COR", "Core"],
        ["MOB", "Mobilidade"],
      ],
    },
    screens: {
      label: "No app",
      items: [
        { src: "/screens/workout.png", alt: "Treino ativo com séries, cargas e repetições" },
        { src: "/screens/arcs.png", alt: "Arcos da temporada em ordem" },
        { src: "/screens/profile.png", alt: "Perfil com patente, nível e páginas da conta" },
      ],
    },
    more: {
      label: "Mais",
      items: [
        ["Limite Quebrado", "Recorde pessoal marcado na hora."],
        ["Sequência", "Semanas seguidas batendo a meta."],
        ["A Batalha", "A competição que fecha a temporada."],
        ["Offline", "Registra sem sinal e sincroniza depois."],
      ],
    },
    integrations: {
      label: "Integrações",
      body: "Garmin, em breve: corridas e outras atividades do relógio entram no diário e dão XP.",
    },
    closing: "Lembre do objetivo.",
    footer: { rights: "Hard To Submit", contact: "Contato" },
  },
  en: {
    htmlLang: "en",
    description:
      "iPhone app for jiu-jitsu strength and conditioning. Log every set; each set becomes XP, level, rank and attributes.",
    nav: { privacy: "Privacy", support: "Support", switchLabel: "Português" },
    soon: "Coming soon to the App Store",
    hero: {
      image: "/screens/home.png",
      imageAlt: "Home screen with rank, XP, the Battle and the workout in progress",
      title: ["Train.", "Never tap."],
      lead: "Strength and conditioning for jiu-jitsu, set by set. Every completed set becomes XP, level, rank and attributes.",
    },
    how: {
      label: "How it works",
      items: [
        {
          title: "Seasons and arcs",
          body: "Plan the year in seasons. Each arc has its workouts and weeks and unlocks the next when it ends. Maintenance is always at hand.",
        },
        {
          title: "Active workout",
          body: "Load and reps for every set, what you did last time and a rest timer that tells you when to go. Fast before pretty.",
        },
        {
          title: "Ranks",
          body: "Every set gives XP. XP raises your level, and your level raises your rank: from Recruit to Commander.",
        },
        {
          title: "Attributes",
          body: "Each block of the workout feeds its own: strength, power, conditioning, core and mobility. See where you are strong and where you fall short.",
        },
      ],
    },
    ranks: {
      label: "Ranks",
      list: ["Recruit", "Private", "Corporal", "Sergeant", "Lieutenant", "Commander"],
    },
    attributes: {
      label: "Attributes",
      list: [
        ["STR", "Strength"],
        ["PWR", "Power"],
        ["GAS", "Conditioning"],
        ["COR", "Core"],
        ["MOB", "Mobility"],
      ],
    },
    screens: {
      label: "In the app",
      items: [
        { src: "/screens/workout.png", alt: "Active workout with sets, loads and reps" },
        { src: "/screens/arcs.png", alt: "The season's arcs in order" },
        { src: "/screens/profile.png", alt: "Profile with rank, level and account pages" },
      ],
    },
    more: {
      label: "More",
      items: [
        ["Limit Broken", "Personal records, marked as they happen."],
        ["Streak", "Weeks in a row hitting your goal."],
        ["The Battle", "The competition that closes the season."],
        ["Offline", "Logs without signal and syncs later."],
      ],
    },
    integrations: {
      label: "Integrations",
      body: "Garmin, coming soon: runs and other watch activities land in your log and give XP.",
    },
    closing: "Remember the goal.",
    footer: { rights: "Hard To Submit", contact: "Contact" },
  },
} as const;
