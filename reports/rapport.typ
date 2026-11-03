#set document(title: "Approche économique du seuil de rétention")

#align(center)[
  #text(size: 20pt, weight: "bold")[Approche économique du seuil de rétention]
  #v(0.5em)
  #text(size: 11pt, style: "italic")[Application au jeu de données Telco]
  #v(0.3em)
  #text(size: 10pt)[Darius Defago · novembre 2026]
]

#v(2em)

= Contexte et enjeu

Dans une entreprise télécom à modèle d'abonnement, le churn (taux de résiliation) augmente au-delà des trois premiers mois de souscription. La perte de revenu est visible et la cause est identifiée dans les grandes lignes, mais l'action à prendre n'est pas évidente. La question opérationnelle est : quels abonnés faut-il contacter en priorité ? 

Répondre à cette question suppose de répondre à une question plus fine. À partir de quelle probabilité de départ envoyer une offre de rétention devient-il rentable ? Avec un seuil trop bas, on gaspille des offres sur des abonnés qui seraient restés. A l'inverse, un seuil trop haut rate des abonnés qu'on aurait pu retenir. La bonne réponse n'est pas la même selon la valeur d'un abonné dans le portefeuille, le coût d'une action de rétention et son efficacité réelle.

L'approche classique consiste à entraîner un modèle prédictif et à retenir un seuil issu d'une contrainte statistique, souvent une contrainte de précision. Cette méthode a le mérite de la simplicité mais ne dit rien sur les montants en jeu. Deux erreurs de classification y ont la même importance, alors que l'une coûte le prix d'une offre gaspillée et l'autre le prix d'un abonné perdu.

L'analyse qui suit reformule la sélection du seuil en question monétaire. Elle applique cette méthode au jeu de données public Telco d'IBM. La recommandation qui en ressort inverse l'intuition habituelle.

Le périmètre couvert ici est celui des abonnés particuliers.

= Analyse du risque de résiliation

Un premier fait ressort immédiatement de l'analyse : Le risque de résiliation n'est pas réparti uniformément dans la durée d'un abonnement. Il est très élevé dans les premiers mois puis chute nettement et se stabilise à un niveau bas. Un abonné qui a passé le cap de la première année a peu de chances de partir, alors qu'un abonné dans son troisième mois est en pleine période à risque.

#figure(
  image("figures/fig1_churn_by_tenure.png", width: 100%),
  caption: [Taux de résiliation par tranche d'ancienneté, calculé sur l'ensemble du jeu Telco.],
)

Le type d'engagement pèse presque autant. Un abonné souscrivant un contrat mensuel a près de quatre fois plus de risques de partir qu'un abonné avec un contrat annuel, et une quinzaine de fois plus qu'un abonné avec un contrat de deux ans. Ce résultat n'est évidemment pas surprenant, un contrat court laissant plus de liberté de partir.

Trois autres facteurs ressortent, chacun associé à un risque plus élevé : la fibre optique, la facturation dématérialisée et le paiement par prélèvement électronique. Ces trois marqueurs ont tendance à aller ensemble, et le profil qui s'en dégage est celui d'un abonné plus digital, qui gère ses services en ligne et dont la relation contractuelle fonctionne sans papier ni intermédiaire, ce qui rend la comparaison et le départ plus faciles.

À l'inverse, les abonnés qui souscrivent des services additionnels comme le support technique ou la sécurité en ligne partent moins. Ce constat mérite cependant d'être lu avec prudence. Il est probable que les abonnés qui prennent ces options soient déjà, par nature, plus engagés dans la relation. Le service additionnel accompagne la fidélité mais ne la crée pas nécessairement. Le raccourci qui consisterait à proposer systématiquement plus d'options à tous les abonnés ne reproduirait pas forcément l'effet observé.

La suite s'appuie sur un modèle prédictif qui exploite ces marqueurs et leurs combinaisons pour estimer, pour chaque abonné, la probabilité qu'il résilie dans les mois qui viennent. Cette probabilité n'est pas une certitude mais un outil de tri. Elle permet de décider de façon informée qui contacter en priorité.

= Approche

La question est : à partir de quelle probabilité de départ envoyer une offre de rétention devient-il rentable ? C'est une question d'argent avant d'être une question statistique. Pour y répondre, il faut arbitrer une dépense. Avant d'envoyer une offre à un abonné, on se demande ce qu'on dépense pour l'envoyer et ce qu'on gagne si elle fonctionne.

Quatre éléments entrent dans ce calcul.

Le premier est ce qu'on gagne en gardant un abonné qui s'apprêtait à partir. Pas son chiffre d'affaires brut, mais ce qu'il laisse en marge à l'entreprise une fois les coûts variables déduits. Un abonné qui facture 70 CHF par mois ne vaut pas 70 CHF à l'entreprise, il vaut la part de ces 70 CHF qui reste après avoir payé le réseau, le support, les licences et les commissions.

Le deuxième est la durée pendant laquelle on récupère cette marge. Un abonné retenu aujourd'hui ne rapporte pas sur un mois, il rapporte sur l'horizon pendant lequel il reste client. Cet horizon n'est pas infini, les abonnés finissent par partir pour d'autres raisons que celles qu'on traite ici. Choisir cet horizon est un vrai choix qui est détaillé en annexe.

Le troisième est le coût de l'action de rétention elle-même. Une offre a un prix : le rabais consenti, l'appel passé par un agent, l'envoi d'un courrier, ou la combinaison des trois. Ce coût est engagé que l'offre fonctionne ou non.

Le quatrième est la probabilité que l'offre fonctionne réellement, c'est-à-dire qu'elle fasse rester un abonné qui serait sinon parti. Cette probabilité est centrale. Une offre qui fonctionne une fois sur trois n'a pas la même rentabilité qu'une offre qui fonctionne deux fois sur trois, pour un même coût.

Ces quatre éléments se combinent. La valeur attendue d'une action de rétention, pour un abonné donné, dépend de la probabilité qu'il parte sans intervention, du gain qu'on retire s'il reste, et du coût qu'on engage dans tous les cas. En fixant un seuil de probabilité de départ au-dessus duquel on agit, on choisit implicitement un équilibre entre ces quantités. Un seuil bas déclenche beaucoup d'actions, dont certaines sur des abonnés qui seraient restés de toute façon, ce qui dilue le gain. Un seuil haut n'agit que sur les cas les plus risqués, au prix de laisser partir des abonnés qu'on aurait pu retenir. Le bon seuil est celui qui maximise la valeur nette totale de la campagne, pas celui qui maximise une métrique statistique sans contrepartie monétaire.

Pour appliquer ce raisonnement, il faut connaître les quatre éléments. Trois d'entre eux ne peuvent pas être lus dans le jeu de données Telco avec une précision suffisante, parce qu'ils dépendent soit de la structure économique du marché (la marge de contribution typique dans le secteur), soit de l'efficacité attendue d'une action commerciale qui n'a pas encore été menée (le coût d'une offre, son taux de succès). Ces trois éléments doivent être posés en hypothèse, à partir de repères de marché raisonnables et vérifiables. Le quatrième, la durée pendant laquelle on récupère la valeur d'un abonné retenu, est de nature différente. Il peut être estimé directement sur les données, parce qu'il s'agit d'observer combien de temps les abonnés restent effectivement.

= Hypothèses économiques

Les repères de marché retenus pour les trois éléments supposés sont les suivants, en ordres de grandeur plausibles pour un opérateur télécom européen en 2026.

La marge de contribution d'un abonné se situe entre 55 et 70% du chiffre d'affaires facturé#footnote[La marge de contribution par abonné, qui ne retient que les coûts variant avec la présence de l'abonné, se distingue de la marge EBITDA au niveau groupe. Les marges EBITDA publiées par les opérateurs européens en 2026 se situent entre 35 et 45% (Swisscom, Salt, Deutsche Telekom, Bouygues Telecom, rapports annuels 2025-2026), mais incluent des coûts fixes indépendants du churn individuel. La fourchette retenue ici est cohérente avec les benchmarks sectoriels Analysys Mason et GSMA Intelligence.]. L'écart entre les deux bornes reflète des différences réelles entre opérateurs, selon la part du réseau en propre, la structure des coûts de support et le mix de services. Pour un abonné à 70 CHF par mois, cela correspond à une marge mensuelle comprise entre 39 et 49 CHF.

Le coût d'une action de rétention proactive se situe entre 25 et 60 CHF par abonné contacté#footnote[Benchmark européen 2026 des coûts de centres d'appels : 2 à 8 euros par contact, 25 à 45 euros par heure d'agent (Yoummday, analyse de marché juillet 2026). La fourchette haute inclut la valeur de l'offre consentie, rabais ou concession commerciale, qui s'ajoute au coût du contact lui-même.]. La fourchette couvre les combinaisons courantes d'un appel sortant, d'un rabais consenti sur quelques mois, ou d'une concession commerciale ponctuelle. Ce coût est engagé que l'offre fonctionne ou non.

Le taux de succès d'une offre proactive, c'est-à-dire la probabilité qu'un abonné à qui on envoie une offre reste effectivement, se situe entre 20 et 35%#footnote[La prise de contact proactive réduit le churn de 15 à 25% selon les benchmarks sectoriels 2026 (Growsurf, Customer Churn Statistics 2026). Une étude publiée dans MDPI en janvier 2026 sur une campagne sortante télécom estime la préservation de revenu à 10% sur 12 mois pour un pilote de 5000 abonnés à risque par mois.]. Ce taux mérite une mise en garde. Les chiffres publiés par les opérateurs sont parfois beaucoup plus flatteurs, mais ils proviennent souvent des équipes de rétention entrante, qui gèrent les appels d'abonnés venant signaler leur départ#footnote[Un cas documenté d'opérateur télécom américain (étude Foundever 2024) montre un taux de sauvetage de 65 à 70% pour une équipe de rétention entrante, chiffre représentatif du secteur et confirmant l'écart avec le sortant proactif.]. Ces appelants sont déjà en train de partir, et la négociation porte sur ce qu'il faut concéder pour les retenir. Le contexte est différent de celui qui nous occupe ici, où l'offre est envoyée proactivement à un abonné qui n'a rien demandé. Les taux de succès du sortant proactif sont systématiquement plus bas que ceux du rétention entrante, et la fourchette retenue reflète cette différence.

Le quatrième élément est l'horizon pendant lequel on récupère la marge d'un abonné retenu. Il est tentant de prendre la durée moyenne des abonnés actuels et d'en faire l'horizon. Ce serait une erreur. La partie "Analyse du risque de résiliation" a établi que le risque de départ est très concentré dans les premiers mois, puis chute. Un abonné qui part après deux mois et un abonné qui reste cinq ans ne sont pas deux instances du même phénomène, ce sont deux populations différentes. L'approche retenue consiste à estimer l'horizon à partir d'une méthode qui respecte la forme du risque dans le temps, en tenant compte du fait que les départs précoces pèsent différemment des départs tardifs. Le détail de la méthode figure en annexe. Le résultat, en pratique, donne un horizon d'environ 55 mois pour un abonné qui a passé la zone de risque initial, soit un peu plus de quatre ans et demi. Cet ordre de grandeur est cohérent avec le secteur, où un abonné stabilisé reste typiquement entre trois et six ans.

Trois des quatre éléments sont donc donnés sous forme de fourchette. Plutôt que de choisir un point unique au milieu de chacune et de suspendre toute la recommandation à ce choix, on travaille en trois scénarios. Un scénario prudent, qui combine les bornes défavorables à la rentabilité d'une action : marge basse, coût d'offre élevé, taux de succès bas. Un scénario optimiste, qui prend les bornes inverses. Un scénario central, qui prend la position médiane de chaque fourchette. Si la recommandation diffère sensiblement entre les trois, c'est que les hypothèses commandent le résultat et qu'il faudra les resserrer avant d'agir. Si elle est à peu près la même, c'est qu'elle est robuste et qu'on peut la retenir sans attendre d'avoir réduit les incertitudes de marché.

= Résultats et recommendation

L'application de la méthode au jeu de données donne un seuil business central à 7%. Il remonte à 11% dans le scénario prudent, et descend à 6% dans le scénario optimiste. La stratégie est cohérente sur les trois scénarios.

Ce seuil désigne environ 70% du portefeuille comme candidats à une offre de rétention. Le gain net attendu de la campagne, c'est-à-dire la marge sauvée moins le coût total des offres envoyées, se situe entre 100 000 CHF dans le scénario prudent et 330 000 CHF dans le scénario optimiste, avec un central autour de 195 000 CHF.

La taille de la cible est inattendue. On attendrait d'une méthode rigoureuse qu'elle resserre le ciblage, pas qu'elle l'élargisse à sept abonnés sur dix. C'est pourtant la bonne approche : un abonné sauvé rapporte en moyenne 2 000 CHF de marge sur la durée pendant laquelle il reste client, pour un coût d'offre de 40 CHF. Cinquante offres gaspillées coûtent ce qu'un seul abonné perdu rapporterait. L'asymétrie est telle qu'il reste rentable d'agir même quand on n'est sûr qu'à 7% que l'abonné allait partir.

Pour mesurer ce que la méthode monétaire gagne, on peut la comparer à la pratique statistique la plus défendable. Celle-ci consiste à exiger qu'au moins la moitié des abonnés contactés soient effectivement des partants, puis à cibler le plus largement possible sous cette contrainte. Appliquée au même jeu de données, elle désigne 44% des abonnés et dégage un gain net de 176 000 CHF. L'écart avec la méthode monétaire est de 19 000 CHF, soit 10% de la valeur accessible. Un modèle optimisé selon les règles de l'art statistique laisse donc un dixième de la valeur sur la table. La rigueur n'est pas en cause. Ce qui manque au modèle, c'est le prix des erreurs qu'il arbitre.

Le passage de 44% à 70% du portefeuille contacté résume la différence. Un critère statistique raisonnable arrête l'arbitrage à 44% parce qu'au-delà la précision du ciblage devient trop basse. Un critère monétaire continue jusqu'à 70% parce que chaque abonné supplémentaire ciblé, même avec une probabilité plus basse de partir, a une valeur sauvée en espérance qui reste supérieure au coût d'une offre.

En pratique, les abonnés désignés par le seuil ne sont pas traités d'un coup. La liste est balayée par vagues, en commençant par les probabilités les plus hautes, puis en descendant au fil des campagnes. La fréquence du scoring et le dimensionnement des équipes de rétention déterminent la cadence. L'intérêt de la méthode est de fournir un critère unique et traçable, applicable à chaque campagne.

= Robustesse et mise en œuvre

La recommandation ne vaut que par ses hypothèses. L'analyse de sensibilité teste cette dépendance en comparant les trois scénarios. Le seuil se déplace entre 7 et 11% selon le scénario. La part du portefeuille désignée se situe entre 57 et 77% selon le scénario. Le gain net varie de 100 000 à 330 000 CHF, mais la direction de l'action ne change pas. Il faut contacter large et accepter de nombreux faux positifs. Le résultat ne dépend donc pas d'un choix précis à l'intérieur des fourchettes.

#figure(
  table(
    columns: (auto, auto, auto, auto),
    align: (left, center, center, right),
    stroke: 0.5pt + gray,
    inset: 8pt,
    table.header(
      [*Scénario*], [*Seuil retenu*], [*Portefeuille ciblé*], [*Gain net attendu*],
    ),
    [Prudent],    [11%], [57%], [103 800 CHF],
    [Central],    [7%],  [70%], [195 300 CHF],
    [Optimiste],  [6%],  [77%], [330 900 CHF],
  ),
  caption: [Comparaison synthétique des trois scénarios. Les trois convergent sur la direction (contacter large), mais le seuil et la part ciblée se déplacent avec les hypothèses. Le gain net varie d'un facteur trois entre le prudent et l'optimiste.],
)

Deux hypothèses pèsent plus que les deux autres. Le coût d'une offre, qui fixe directement la dépense de chaque contact. Le taux de succès réel, qui détermine combien d'abonnés ciblés sont effectivement retenus. La marge de contribution et l'horizon de valeur jouent aussi, mais leur effet est plus modéré dans les plages retenues. Si le coût d'offre passait de 40 à 60 CHF, ou si le taux de succès tombait de 27 à 20%, la recommandation glisserait vers le scénario prudent sans changer de nature.

Ces deux hypothèses sont parmi les plus faciles à vérifier en campagne. Le coût réel par abonné contacté se lit sur les factures des équipes et des canaux. Pour le taux de succès réel, on suit pendant six à douze mois une cohorte d'abonnés contactés et une cohorte comparable non contactée. La marge et l'horizon demandent plus d'effort pour être réétalonnés, mais ils sont plus stables dans le temps, et une révision annuelle suffit.

Côté exécution, le modèle score périodiquement l'ensemble du portefeuille et produit pour chaque abonné une probabilité de résiliation calibrée. Les abonnés qui passent le seuil sont inscrits sur la liste de rétention, triée par probabilité décroissante. Les équipes la traitent par vagues, en commençant par le haut. La capacité des équipes détermine la cadence. Chaque campagne enregistre les envois et leurs résultats au bout du délai de mesure, et ces résultats alimentent une boucle de retour à deux niveaux : la calibration du modèle, et la mise à jour des hypothèses économiques.

Le dispositif s'affine à mesure qu'il tourne. La première campagne s'appuie sur les hypothèses de marché, les suivantes sur les mesures issues des précédentes. Si les mesures internes contredisent les repères de marché, ce sont elles qui prévalent, puisqu'elles décrivent la réalité propre de l'entreprise. Quand elles les confirment, la méthode y gagne surtout en crédibilité.

= Conclusion

La sélection d'une cible de rétention gagne à être traitée comme une décision économique, pas comme un ajustement statistique. Les deux approches aboutissent à des listes différentes, et l'écart économique entre elles est de l'ordre de 10% dans la pratique la plus défendable, davantage dans les pratiques courantes. Le gain tient à l'objectif qu'on fixe au modèle, pas à sa sophistication.

Le décisionnaire peut en tirer une décision simple. Lancer une première campagne de rétention au scénario central, en commençant par les abonnés dont la probabilité est la plus haute. Mesurer sur cette première vague le taux de succès réel, en comparant la cohorte contactée à une cohorte comparable laissée de côté. À l'issue des six à douze mois de mesure, décider si l'hypothèse du scénario central tient, ou si elle doit être resserrée vers le prudent.

Trois réserves accompagnent cette recommandation. Le modèle a été entraîné sur un jeu de données public représentatif d'un opérateur grand public standard, pas sur les données propres de l'entreprise. Avant toute mise en production, il devra être ré-entraîné sur les données internes et sa calibration vérifiée. La méthode suppose que le marché reste dans sa configuration actuelle. Une rupture concurrentielle, une bascule tarifaire majeure ou l'arrivée d'un nouvel entrant modifieraient les hypothèses économiques et imposeraient un réétalonnage. Enfin, le portefeuille B2B n'est pas couvert par cette analyse. Les dynamiques de churn y sont différentes et demandent une analyse à part.

= Annexe A : modèle et calibration

Le classifieur est un modèle supervisé binaire entraîné sur le jeu Telco (7043 abonnés, 20 variables, 26,5% de churn). Trois modèles ont été comparés dans la phase exploratoire. La régression logistique sert de référence et atteint un ROC AUC autour de 0,82, avec un F1 de 0,61 sur la classe churn. Elle montre que la structure du problème reste assez linéaire une fois l'encodage one-hot appliqué. La Random Forest n'apporte pas de gain significatif, ce qui confirme l'absence d'interactions complexes à capter. XGBoost a été retenu pour la version finale. Il capture mieux la non-linéarité de la relation entre ancienneté et churn, en particulier le fait que le risque est très concentré dans les premiers mois puis chute. Il tolère sans mal les variables one-hot peu représentées et atteint un ROC AUC de 0,848 sur le jeu de test.

Les hyperparamètres sont ajustés par `RandomizedSearchCV` sur 20 itérations, en validation croisée stratifiée à 5 folds, avec le ROC AUC comme critère d'optimisation. Les plages explorées couvrent la profondeur maximale, le taux d'apprentissage, le nombre d'arbres, et les taux de sous-échantillonnage sur les lignes et les colonnes. La recherche s'effectue sur une partie seulement du jeu d'entraînement, pour que l'étape de calibration qui suit se fasse sur des données que l'estimateur n'a jamais vues.

La séparation des données est à trois niveaux. Un premier partage à 80/20 met de côté le jeu de test pour l'évaluation finale. Au sein de l'ensemble d'entraînement, un second partage à 80/20 isole deux sous-ensembles. Le premier sert à la recherche d'hyperparamètres et à l'ajustement du modèle. Le second est réservé à la calibration des probabilités. Les trois découpages sont stratifiés sur la variable cible pour préserver la proportion de churn dans chaque sous-ensemble. Le modèle finalisé combine un `CalibratedClassifierCV` et un `FrozenEstimator` qui empêche la ré-estimation du modèle sous-jacent pendant la calibration.

La calibration n'est pas un ajustement cosmétique dans ce projet. Elle conditionne la validité du raisonnement économique de l'annexe B. La sélection du seuil en francs suppose que la probabilité produite par le modèle est une vraie fréquence : qu'un abonné auquel le modèle attribue 15% de probabilité de départ ait effectivement une chance sur six ou sept de partir. Si cette condition n'est pas remplie, la formule qui multiplie cette probabilité par la valeur d'un abonné conservé donne un nombre qui ressemble à une espérance de gain sans en être une. XGBoost, comme la plupart des modèles de ce type, produit des scores dont l'ordre est généralement bon mais dont le niveau absolu peut être biaisé, en particulier aux extrémités de l'échelle. L'étape de calibration corrige ce biais et rend les probabilités utilisables.

= Annexe B : sélection monétaire du seuil

La sélection du seuil de décision est traitée comme un problème d'optimisation économique. On définit la valeur nette d'une campagne au seuil $t$ par :

$ "NetValue"(t) = p_"save" times sum_(i in "TP") V_("sub",i) - C_"offer" times (|"TP"| + |"FP"|) $

où TP désigne les abonnés correctement signalés (seuil franchi et vrai churner), FP les abonnés signalés à tort, $p_"save"$ la probabilité qu'une offre proactive retienne un vrai churner, $V_("sub",i)$ la valeur actualisée d'un abonné retenu, et $C_"offer"$ le coût unitaire d'une action de rétention. La valeur par abonné est calculée au niveau individuel, $V_("sub",i) = "MonthlyCharges"_i times "margin" times "horizon"_m$, ce qui prend en compte la dispersion des factures mensuelles plutôt que de passer par une moyenne agrégée. Le seuil optimal est obtenu en parcourant une grille de 0,01 à 0,99 par pas de 0,01 et en retenant la valeur de $t$ qui maximise $"NetValue"(t)$.

Un contrôle de cohérence analytique accompagne cette optimisation numérique. En moyenne sur l'ensemble des abonnés, l'offre devient rentable tant que $p("churn") times p_"save" times V_"sub,mean"$ dépasse $C_"offer"$, ce qui donne un seuil fermé $t^* = C_"offer" / (p_"save" times V_"sub,mean")$. Comparer ce seuil fermé au seuil obtenu par balayage est un indicateur utile. Un écart faible signale une calibration des probabilités satisfaisante et une dispersion des valeurs d'abonné modérée. Un écart marqué indiquerait soit un défaut de calibration, soit une dispersion des $V_"sub"$ assez forte pour que le seuil moyen ne soit plus représentatif. Sur les données Telco, les deux valeurs restent proches dans le scénario central (0,07 pour le balayage, 0,071 pour la formule), ce qui confirme la qualité de la calibration.

L'horizon de valeur est estimé par la durée moyenne restreinte de survie, calculée à partir d'un estimateur de Kaplan-Meier appliqué à la variable d'ancienneté, en traitant le churn comme événement et les abonnés encore actifs comme censures à droite. L'estimateur intègre la fonction de survie jusqu'à une borne (72 mois, qui correspond à la valeur maximale observée dans le jeu de données) et renvoie un nombre de mois pondérés par la probabilité conditionnelle de survie à chaque instant. Sur l'ensemble du jeu de données, la valeur obtenue est de 54,5 mois.

#figure(
  image("figures/fig2_survival_km.png", width: 100%),
  caption: [Fonction de survie estimée par Kaplan-Meier sur l'ancienneté des abonnés. L'aire sous la courbe entre 0 et 72 mois donne la durée moyenne restreinte de survie, soit 54,5 mois.],
)

Trois approches naïves auraient été plus simples mais fausses. La durée moyenne des abonnés actuellement observés (32 mois sur ce jeu) sous-estime l'horizon réel parce qu'elle intègre massivement des abonnés en cours de vie, dont la durée finale sera forcément supérieure à celle mesurée aujourd'hui. La durée moyenne des seuls abonnés déjà partis (18 mois) décrit une population biaisée vers les départs précoces, qui n'a pas de rapport avec l'horizon d'un abonné qu'on cherche à stabiliser. L'inverse du taux de churn mensuel (122 mois) suppose un risque de départ constant dans le temps, ce que les données contredisent. La durée moyenne restreinte évite ces trois pièges parce qu'elle ne pose aucune hypothèse sur la forme du risque dans le temps.

Les trois paramètres supposés sont déclinés en trois scénarios qui bornent la recommandation. Le scénario prudent combine une marge basse (0,55), un coût d'offre élevé (60 CHF) et un taux de succès faible (0,20). Le scénario optimiste combine les bornes inverses (0,70, 25 CHF, 0,35). Le scénario central occupe la position médiane (0,60, 40 CHF, 0,27). La durée moyenne restreinte est partagée par les trois scénarios, puisqu'elle est estimée à partir des données et non supposée.

Une analyse de sensibilité à l'horizon seul complète l'ensemble. Elle multiplie la durée moyenne restreinte par les facteurs 0,6 à 1,4 et vérifie que le seuil optimal du scénario central ne bouge pas de façon marquée sur cette plage. Elle couvre à la fois l'incertitude sur le choix de la borne haute et l'effet d'une actualisation financière implicite. Sur les données Telco, le seuil reste stable dans cette plage, ce qui confirme que la recommandation ne dépend pas d'un choix précis d'horizon.

= Annexe C : pipeline d'inférence

Le code est organisé en quatre fichiers, chacun responsable d'une étape. Le fichier `preprocessing.py` contient la transformation des variables, en particulier l'encodage, le nettoyage des types et le réalignement sur un schéma de colonnes attendu. Le fichier `train.py` orchestre l'entraînement, la calibration et l'évaluation. Le fichier `business_value.py` isole le raisonnement économique, c'est-à-dire la sélection du seuil, la définition des scénarios et les analyses de sensibilité. Le fichier `predict.py` consomme les objets produits à l'entraînement et renvoie les signalements pour une liste d'abonnés passée en entrée. Les quatre fichiers ne partagent que des interfaces nettes, et aucune logique métier n'est dupliquée entre eux.

Trois objets sont sérialisés à la fin de l'entraînement : le modèle calibré (`model.pkl`), le schéma des colonnes attendues en entrée (`columns.pkl`) et un dictionnaire des seuils par scénario accompagnés des hypothèses économiques qui les ont produits (`threshold.pkl`). L'étape d'inférence recharge ces trois objets et les applique à un fichier d'abonnés par traitement en lot, avec un choix explicite du scénario (prudent, central, optimiste) passé en argument de la ligne de commande. L'équipe de rétention peut donc rejouer la même liste sous plusieurs scénarios sans avoir à relancer l'entraînement, ce qui est utile pour comparer les tailles de cible et les gains attendus avant de décider.

La validation du schéma à l'inférence est stricte et prévue pour ne pas échouer en silence. Si une colonne attendue manque dans le fichier d'entrée, le code lève une exception explicite avant tout appel au modèle. Cette discipline évite ce qui est probablement le défaut le plus coûteux d'un code de prédiction en production : la prédiction silencieusement fausse, où le modèle reçoit un vecteur de variables aligné sur un mauvais schéma et renvoie une probabilité qui n'a aucun sens. Un échec explicite à l'entrée transforme ce type de problème en incident immédiat et visible plutôt qu'en dérive qui contamine les campagnes successives.

La traçabilité des hypothèses économiques jusqu'à la prédiction individuelle est le trait le plus spécifique du pipeline. Le fichier des seuils ne contient pas que les valeurs numériques des trois seuils, il embarque aussi, pour chaque scénario, les quatre hypothèses qui les ont produits : marge de contribution, coût d'offre, taux de succès attendu et horizon de valeur. Un abonné signalé peut donc être expliqué a posteriori en remontant du signalement vers la probabilité, puis vers le seuil, puis vers les hypothèses et le scénario sous lequel il a été produit. Cette chaîne de traçabilité est utile en audit interne, en revue des hypothèses, et au moment de basculer d'un scénario à l'autre.