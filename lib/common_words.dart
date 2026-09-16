// =============================================================================
// common_words.dart
// =============================================================================
// A real (if not exhaustive) dictionary of common English words.
//
// This is used by text_analysis.dart to do genuine work: scanning a real
// Claude API response and flagging words that AREN'T in this common-word
// list, then finding the closest dictionary word via Levenshtein (edit)
// distance — the same basic idea a spell-checker or "unusual/possibly
// hallucinated term" highlighter would use.
//
// Because most AI responses are full of topic-specific vocabulary, names,
// and technical terms that won't be in a list of common words, nearly every
// unique word in a real response ends up triggering a full dictionary scan.
// That's what makes this genuinely CPU-intensive on longer responses — no
// artificial delay required.
// =============================================================================

const List<String> commonEnglishWords = [
  'the','be','to','of','and','a','in','that','have','it','for','not','on','with','he','as','you','do','at',
  'this','but','his','by','from','they','we','say','her','she','or','an','will','my','one','all','would','there',
  'their','what','so','up','out','if','about','who','get','which','go','me','when','make','can','like','time',
  'no','just','him','know','take','people','into','year','your','good','some','could','them','see','other','than',
  'then','now','look','only','come','its','over','think','also','back','after','use','two','how','our','work',
  'first','well','way','even','new','want','because','any','these','give','day','most','us','is','was','are',
  'been','has','had','were','said','did','getting','made','find','here','thing','many','before','must','through',
  'during','without','again','around','because','between','each','few','more','most','other','some','such','only',
  'own','same','than','too','very','just','should','now','person','place','thing','system','process','result',
  'change','study','part','group','number','case','point','fact','world','area','money','story','information',
  'water','room','area','money','lot','right','study','book','eye','job','word','business','issue','side',
  'kind','head','house','service','friend','father','power','hour','game','line','end','member','law','car',
  'city','community','name','president','team','minute','idea','body','information','face','night','country',
  'problem','need','feel','seem','leave','call','ask','show','try','change','play','run','move','live','believe',
  'bring','happen','write','provide','sit','stand','lose','pay','meet','include','continue','set','learn',
  'change','lead','understand','watch','follow','stop','create','speak','read','allow','add','spend','grow',
  'open','walk','win','offer','remember','love','consider','appear','buy','wait','serve','die','send','expect',
  'build','stay','fall','cut','reach','kill','remain','suggest','raise','pass','sell','require','report','decide',
  'pull','return','explain','hope','develop','carry','break','receive','agree','support','hit','produce','eat',
  'cover','catch','draw','choose','cause','point','listen','realize','place','close','act','reduce','base',
  'design','apply','identify','determine','prepare','indicate','involve','protect','establish','achieve',
  'increase','maintain','estimate','organize','improve','address','affect','avoid','obtain','claim','argue',
  'assume','conduct','contain','define','demonstrate','ensure','examine','exist','generate','include','incorporate',
  'interpret','participate','perform','possess','recognize','reflect','regard','remove','represent','respond',
  'reveal','significant','structure','suffer','support','tend','treat','vary','specific','general','common',
  'important','different','large','small','local','social','national','international','political','economic',
  'public','private','human','physical','natural','legal','medical','scientific','financial','environmental',
  'educational','historical','cultural','technical','digital','online','modern','traditional','simple','complex',
  'difficult','easy','possible','impossible','likely','unlikely','clear','similar','related','specific',
  'available','current','recent','early','late','final','initial','primary','secondary','major','minor',
  'positive','negative','effective','efficient','successful','popular','famous','powerful','strong','weak',
  'high','low','deep','wide','narrow','short','long','old','young','new','fast','slow','hot','cold','hard','soft',
  'heavy','light','clean','dirty','safe','dangerous','healthy','sick','happy','sad','angry','afraid','tired',
  'excited','interested','bored','confused','surprised','worried','proud','ashamed','careful','curious',
  'creative','honest','kind','patient','polite','rude','selfish','generous','brave','lazy','smart','wise',
  'foolish','confident','nervous','calm','friendly','serious','funny','beautiful','ugly','attractive','plain',
  'expensive','cheap','free','rich','poor','busy','quiet','loud','empty','full','open','closed','clean','dirty',
  'wet','dry','bright','dark','sharp','dull','smooth','rough','thick','thin','wide','narrow','tight','loose',
  'analysis','approach','area','assessment','assumption','authority','benefit','category','chapter','community',
  'complexity','component','concept','conclusion','context','contract','contribution','corporation','creation',
  'culture','data','debate','definition','design','development','discussion','distribution','document',
  'economy','education','element','emphasis','environment','equation','evidence','evolution','example',
  'experience','expert','factor','feature','framework','function','goal','hypothesis','image','impact',
  'implementation','implication','individual','industry','initiative','innovation','instance','institution',
  'instruction','integration','interpretation','investigation','involvement','issue','justice','knowledge',
  'language','layer','legislation','limitation','literature','location','maintenance','management','material',
  'mechanism','method','model','motivation','movement','network','object','objective','observation','opinion',
  'opportunity','option','organization','outcome','participant','perception','perspective','phase',
  'phenomenon','philosophy','policy','population','position','potential','practice','presence','principle',
  'priority','procedure','production','proportion','proposal','protocol','purpose','quality','quantity',
  'range','ratio','reaction','reality','reason','recommendation','reference','region','relationship','relevance',
  'reliability','requirement','research','resource','response','responsibility','restriction','review',
  'revolution','role','sample','scenario','sector','sequence','session','significance','situation','skill',
  'society','solution','source','specification','stability','stage','standard','statement','statistic',
  'strategy','structure','style','subject','substance','summary','support','survey','symbol','system',
  'technique','technology','tendency','theme','theory','tool','topic','tradition','trend','type','unit',
  'value','variable','variation','version','vision','volume','network','artificial','intelligence','model',
  'algorithm','computer','software','hardware','application','platform','feature','update','version','device',
  'internet','website','server','database','security','privacy','encryption','password','account','profile',
  'message','email','notification','setting','preference','interface','experience','design','layout','screen',
  'button','menu','icon','image','video','audio','file','folder','document','format','content','media',
];
