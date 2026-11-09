# Builds Data\SpellData.lua from THIS CLIENT'S OWN spell tables, so every cooldown,
# duration and icon is what the game itself says (not retail, not classic wikis).
#
#   1. extract the tables (OctoBG's MPQ reader; highest patch wins, patch-O is the
#      server's spell file, patch-Z only adds the user's ported models):
#        OctoBG\tools\MpqRead.ps1 -OutDir <dir> -Names @("DBFilesClient\Spell.dbc", ...)
#   2. powershell -ExecutionPolicy Bypass -File tools\BuildSpellData.ps1 -Dbc <dir>
#
# The list below only says WHICH spells matter and how to show them:
#   class|spell name|kind|tier[|flags]
#   kind: interrupt silence stun cc root defense immune offense mobility heal utility
#   tier: pin = always shown on the frame (dim while ready)
#         on  = pops up on the frame while on cooldown
#         off = tracked and listed in the options, not shown unless switched on
#   flags: T talent (only shown once seen), P cast by a pet, cd=<s> item cooldown,
#          ids=<a,b,c> extra spell ids, id=<a,b> exactly these spell ids
param(
  [Parameter(Mandatory=$true)][string]$Dbc,
  [string]$Out = "",
  [string]$Review = ""
)
$ErrorActionPreference = "Stop"
if (-not $Out) { $Out = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "..\Data\SpellData.lua" }

$curated = @'
WARRIOR|Pummel|interrupt|pin
WARRIOR|Shield Bash|interrupt|pin
WARRIOR|Intercept|stun|pin
WARRIOR|Intimidating Shout|cc|pin
WARRIOR|Disarm|cc|pin
WARRIOR|Berserker Rage|defense|pin
WARRIOR|Concussion Blow|stun|on|T
WARRIOR|Charge|mobility|on
WARRIOR|Intervene|defense|on
WARRIOR|Cyclone|immune|on
WARRIOR|Death Wish|offense|on|T
WARRIOR|Recklessness|offense|on
WARRIOR|Retaliation|defense|on
WARRIOR|Shield Wall|defense|on
WARRIOR|Last Stand|defense|on
WARRIOR|Sweeping Strikes|offense|off
WARRIOR|Bloodrage|utility|off
WARRIOR|Master Strike|offense|off
WARRIOR|Mortal Strike|offense|off|T
WARRIOR|Bloodthirst|offense|off|T
WARRIOR|Shield Slam|offense|off
WARRIOR|Overpower|offense|off
WARRIOR|Whirlwind|offense|off
WARRIOR|Thunder Clap|offense|off
WARRIOR|Revenge|offense|off
WARRIOR|Shield Block|defense|off
ROGUE|Kick|interrupt|pin
ROGUE|Kidney Shot|stun|pin
ROGUE|Blind|cc|pin
ROGUE|Vanish|defense|pin
ROGUE|Evasion|defense|pin
ROGUE|Sprint|mobility|pin
ROGUE|Deadly Throw|interrupt|off
ROGUE|Gouge|cc|on
ROGUE|Preparation|utility|on|T
ROGUE|Cold Blood|offense|on|T
ROGUE|Adrenaline Rush|offense|on|T
ROGUE|Blade Flurry|offense|on|T
ROGUE|Smoke Bomb|defense|on|T
ROGUE|Flourish|defense|on
ROGUE|Mark for Death|offense|on|T
ROGUE|Shadow of Death|offense|on|T
ROGUE|Premeditation|offense|off|T
ROGUE|Ghostly Strike|defense|off|T
ROGUE|Surprise Attack|offense|off
ROGUE|Riposte|offense|off|T
ROGUE|Distract|utility|off
ROGUE|Feint|utility|off
ROGUE|Stealth|utility|off
MAGE|Counterspell|interrupt|pin
MAGE|Blink|mobility|pin
MAGE|Ice Block|immune|pin|T
MAGE|Frost Nova|root|pin
MAGE|Cold Snap|utility|on|T
MAGE|Presence of Mind|offense|on|T
MAGE|Arcane Power|offense|on|T
MAGE|Combustion|offense|on|T
MAGE|Blast Wave|root|on|T
MAGE|Ice Barrier|defense|on|T
MAGE|Evocation|utility|on
MAGE|Cone of Cold|root|off
MAGE|Icicles|offense|off|T
MAGE|Fire Blast|offense|off
MAGE|Fire Ward|defense|off
MAGE|Frost Ward|defense|off
MAGE|Arcane Surge|offense|off
MAGE|Arcane Rupture|offense|off
PRIEST|Silence|silence|pin|T
PRIEST|Psychic Scream|cc|pin
PRIEST|Fear Ward|defense|pin
PRIEST|Power Infusion|offense|on|T
PRIEST|Inner Focus|offense|on|T
PRIEST|Desperate Prayer|heal|on
PRIEST|Shadow Mend|heal|on
PRIEST|Chastise|stun|on
PRIEST|Ascendance|immune|on|T
PRIEST|Grace of the Sunwell|defense|on
PRIEST|Elune's Grace|defense|on
PRIEST|Avatar|defense|on
PRIEST|Fade|utility|off
PRIEST|Power Word: Shield|defense|off
PRIEST|Pain Spike|offense|off
PRIEST|Lightwell|heal|off
PRIEST|Feedback|defense|off
PRIEST|Vampiric Embrace|utility|off|T
PRIEST|Mind Blast|offense|off
PRIEST|Devouring Plague|offense|off
PRIEST|Sun's Embrace|utility|off
PRIEST|Light of An'she|heal|off
WARLOCK|Spell Lock|silence|pin|TP
WARLOCK|Death Coil|cc|pin
WARLOCK|Howl of Terror|cc|pin
WARLOCK|Fel Domination|utility|on|T
WARLOCK|Demonic Empowerment|offense|on
WARLOCK|Power Overwhelming|offense|on|T
WARLOCK|Devour Magic|utility|on|P
WARLOCK|Inferno|utility|on
WARLOCK|Shadowburn|offense|off|T
WARLOCK|Conflagrate|offense|off|T
WARLOCK|Shadow Ward|defense|off
WARLOCK|Soul Fire|offense|off
WARLOCK|Dark Harvest|offense|off
WARLOCK|Curse of Doom|offense|off
PALADIN|Hammer of Justice|stun|pin
PALADIN|Repentance|cc|pin|T
PALADIN|Divine Shield|immune|pin
PALADIN|Hand of Protection|immune|pin
PALADIN|Hand of Freedom|defense|pin
PALADIN|Divine Protection|immune|on
PALADIN|Lay on Hands|heal|on
PALADIN|Bulwark of the Righteous|defense|on
PALADIN|Holy Shock|heal|off|T
PALADIN|Greater Blessing of Sacrifice|defense|off
PALADIN|Consecration|offense|off
PALADIN|Exorcism|offense|off
PALADIN|Hammer of Wrath|offense|off
PALADIN|Holy Shield|defense|off|T
PALADIN|Crusader Strike|offense|off
PALADIN|Holy Strike|offense|off
PALADIN|Conviction|offense|off
PALADIN|Holy Wrath|offense|off
PALADIN|Judgement|offense|off
SHAMAN|Earth Shock|interrupt|pin
SHAMAN|Grounding Totem|defense|pin
SHAMAN|Ancestral Swiftness|offense|on|T
SHAMAN|Elemental Mastery|offense|on|T
SHAMAN|Bloodlust|offense|on|T
SHAMAN|Spirit Link|defense|on|T
SHAMAN|Mana Tide Totem|utility|on|T
SHAMAN|Earthbind Totem|root|on
SHAMAN|Earthquake|stun|on
SHAMAN|Totemic Slam|offense|on
SHAMAN|Flame Shock|offense|off
SHAMAN|Frost Shock|root|off
SHAMAN|Purge|utility|off
SHAMAN|Stormstrike|offense|off|T
SHAMAN|Lava Lash|offense|off
SHAMAN|Lightning Strike|offense|off
SHAMAN|Chain Lightning|offense|off
SHAMAN|Stoneclaw Totem|defense|off
SHAMAN|Reincarnation|utility|off
DRUID|Feral Charge|interrupt|pin|T
DRUID|Bash|stun|pin
DRUID|Barkskin|defense|pin
DRUID|Innervate|heal|on
DRUID|Nature's Swiftness|offense|on|T
DRUID|Nature's Grasp|root|on
DRUID|Dash|mobility|on
DRUID|Mangle|stun|on
DRUID|Barkskin (Feral)|defense|on
DRUID|Frenzied Regeneration|defense|on
DRUID|Berserk|offense|on|T
DRUID|Tranquility|heal|on
DRUID|Rebirth|utility|on
DRUID|Swiftmend|heal|off|T
DRUID|Enrage|utility|off
DRUID|Hurricane|offense|off
DRUID|Savage Bite|offense|off
DRUID|Prowl|utility|off
HUNTER|Scatter Shot|cc|pin|T
HUNTER|Freezing Trap|cc|pin
HUNTER|Deterrence|defense|pin|T
HUNTER|Feign Death|defense|pin
HUNTER|Intimidation|stun|on|TP
HUNTER|Wyvern Sting|cc|on|T
HUNTER|Bestial Wrath|offense|on|T
HUNTER|Rapid Fire|offense|on
HUNTER|Readiness|utility|on
HUNTER|Aspect of the Turtle|immune|on
HUNTER|Grace|defense|on
HUNTER|Frost Trap|root|off
HUNTER|Immolation Trap|offense|off
HUNTER|Explosive Trap|offense|off
HUNTER|Disengage|utility|off
HUNTER|Counterattack|root|off|T
HUNTER|Concussive Shot|root|off
HUNTER|Tranquilizing Shot|utility|off
HUNTER|Aimed Shot|offense|off
HUNTER|Multi-Shot|offense|off
HUNTER|Arcane Shot|offense|off
HUNTER|Viper Sting|utility|off
HUNTER|Flare|utility|off
HUNTER|Kill Command|offense|off
RACE:Human|Perception|utility|pin
RACE:Dwarf|Stoneform|defense|pin
RACE:NightElf|Shadowmeld|defense|pin
RACE:Gnome|Escape Artist|mobility|pin
RACE:Orc|Blood Fury|offense|pin
RACE:Scourge|Will of the Forsaken|defense|pin
RACE:Tauren|War Stomp|stun|pin
RACE:Troll|Berserking|offense|pin
ITEM|Insignia|defense|pin|cd=180,id=52317;5579;23273;23274;23276;23277,icon=INV_Jewelry_TrinketPVP_02
ITEM|Free Action|defense|on|cd=120,id=6615
ITEM|Living Free Action|defense|on|cd=120,id=24364
ITEM|Invulnerability|immune|on|cd=120,id=3169
ITEM|Tidal Charm|stun|on|cd=900,id=835
'@

# crowd control and other auras made by things other than a class spell, by name
$extraAuras = @(
  "Intercept Stun","Charge Stun","Counterspell - Silenced","Improved Hamstring","Blackout","Impact",
  "Mace Stun Effect","Stun","Seal of Justice","Reckless Charge","Net-o-Matic","Sleep","Pounce","Cheap Shot",
  "Garrote - Silence","Improved Concussive Shot","Starfire Stun","Aftermath","Feral Charge Effect",
  "Entrapment","Frostbite","Improved Wing Clip","Sap","Polymorph","Hibernate","Shackle Undead","Banish",
  "Seduction","Fear","Mind Control","Tidal Charm","Thorium Grenade","Iron Grenade","Gnomish Mind Control Cap"
)

$src = @"
using System;
using System.IO;
using System.Text;
using System.Linq;
using System.Collections.Generic;
public class Dbc {
  public int Records, Fields, RecSize, StrSize; public byte[] D; int strBase;
  public Dbc(string path) {
    D = File.ReadAllBytes(path);
    Records = BitConverter.ToInt32(D, 4); Fields = BitConverter.ToInt32(D, 8);
    RecSize = BitConverter.ToInt32(D, 12); StrSize = BitConverter.ToInt32(D, 16);
    strBase = 20 + Records * RecSize;
  }
  public int I(int r, int f) { return BitConverter.ToInt32(D, 20 + r * RecSize + f * 4); }
  public string S(int r, int f) {
    int o = I(r, f); if (o <= 0 || o >= StrSize) return "";
    int p = strBase + o; int e = p; while (e < D.Length && D[e] != 0) e++;
    return Encoding.UTF8.GetString(D, p, e - p);
  }
}
public static class Build {
  // Spell.dbc 1.12 columns
  const int CAT=2, DISPEL=4, MECH=5, ATTR=6, CASTIDX=18, REC=19, CREC=20, INTFLAGS=21, DURIDX=30, EFF=61, EFFMECH=79,
            AURA=91, ITEMTYPE=103, MISC=106, TRIG=109, BASE=76, ICON=117, NAME=120, RANK=129, DESC=138, FAM=160, FF=161, PREV=165, SCHOOL=1;
  static string Q(string s) { return s.Replace("\\","\\\\").Replace("\"","\\\""); }
  static string Sec(int ms) { double s = ms/1000.0; return s.ToString(System.Globalization.CultureInfo.InvariantCulture); }
  public static string Run(string dir, string curated, string[] extra, string outPath, string reviewPath) {
    var spell = new Dbc(dir + "\\patch-O\\DBFilesClient_Spell.dbc");
    var icons = new Dbc(dir + "\\patch-O\\DBFilesClient_SpellIcon.dbc");
    var dur = new Dbc(dir + "\\patch-4\\DBFilesClient_SpellDuration.dbc");
    var casts = new Dbc(dir + "\\patch\\DBFilesClient_SpellCastTimes.dbc");
    var sla = new Dbc(dir + "\\patch-5\\DBFilesClient_SkillLineAbility.dbc");
    var sl = new Dbc(dir + "\\patch-5\\DBFilesClient_SkillLine.dbc");
    var talent = new Dbc(dir + "\\patch-4\\DBFilesClient_Talent.dbc");
    var tab = new Dbc(dir + "\\patch-4\\DBFilesClient_TalentTab.dbc");

    var iconName = new Dictionary<int,string>();
    for (int r=0;r<icons.Records;r++) { string p = icons.S(r,1); iconName[icons.I(r,0)] = p.Substring(p.LastIndexOf('\\')+1); }
    var durMs = new Dictionary<int,int>();
    for (int r=0;r<dur.Records;r++) durMs[dur.I(r,0)] = dur.I(r,1);
    var castMs = new Dictionary<int,int>();
    for (int r=0;r<casts.Records;r++) castMs[casts.I(r,0)] = casts.I(r,1);
    var row = new Dictionary<int,int>();
    var byName = new Dictionary<string,List<int>>();
    for (int r=0;r<spell.Records;r++) {
      int id = spell.I(r,0); row[id] = r;
      string n = spell.S(r,NAME); List<int> l;
      if (!byName.TryGetValue(n,out l)) { l = new List<int>(); byName[n]=l; }
      l.Add(id);
    }
    // what a class can learn: SkillLineAbility on a class / racial skill line
    var skCat = new Dictionary<int,int>();
    for (int r=0;r<sl.Records;r++) skCat[sl.I(r,0)] = sl.I(r,1);
    var learnable = new HashSet<int>();
    var classSkill = new HashSet<int>();   // class and racial lines only, not professions
    var learnClass = new Dictionary<int,int>();
    for (int r=0;r<sla.Records;r++) {
      int c; if (!skCat.TryGetValue(sla.I(r,1),out c) || (c!=7 && c!=11 && c!=9)) continue;
      int id = sla.I(r,2); learnable.Add(id);
      if (c==7) classSkill.Add(id);
      int m = sla.I(r,4); if (m!=0) learnClass[id]=m;
    }
    // talents: spell -> tab name, cooldown mods by family
    var tabName = new Dictionary<int,string>();
    for (int r=0;r<tab.Records;r++) tabName[tab.I(r,0)] = tab.S(r,1);
    var talentTab = new Dictionary<int,string>();
    var mods = new List<int[]>();  // family, mask, amount (best rank), pct
    for (int r=0;r<talent.Records;r++) {
      string tname; tabName.TryGetValue(talent.I(r,1),out tname);
      var best = new Dictionary<int,int>();
      for (int k=4;k<=12;k++) {
        int id = talent.I(r,k); int rr; if (id<=0 || !row.TryGetValue(id,out rr)) continue;
        talentTab[id] = tname;
        for (int e=0;e<3;e++) {
          if (spell.I(rr,EFF+e)==36) talentTab[spell.I(rr,TRIG+e)] = tname;
          int au = spell.I(rr,AURA+e);
          if ((au==107||au==108) && spell.I(rr,MISC+e)==11) {
            int mask = spell.I(rr,ITEMTYPE+e); int amt = spell.I(rr,BASE+e)+1;
            mods.Add(new[]{ spell.I(rr,FAM), mask, amt, au==108?1:0 });
          }
        }
      }
    }
    var classFam = new Dictionary<string,int>{{"MAGE",3},{"WARRIOR",4},{"WARLOCK",5},{"PRIEST",6},{"DRUID",7},{"ROGUE",8},{"HUNTER",9},{"PALADIN",10},{"SHAMAN",11}};
    var classBit = new Dictionary<string,int>{{"WARRIOR",1},{"PALADIN",2},{"HUNTER",4},{"ROGUE",8},{"PRIEST",16},{"SHAMAN",64},{"MAGE",128},{"WARLOCK",256},{"DRUID",1024}};

    Func<int,int> Cd = rr => Math.Max(spell.I(rr,REC), spell.I(rr,CREC));
    Func<int,int> DurOf = rr => { int d; durMs.TryGetValue(spell.I(rr,DURIDX),out d); return d; };

    var sb = new StringBuilder();
    var rv = new StringBuilder();
    var warn = new List<string>();
    sb.AppendLine("-- GENERATED by tools\\BuildSpellData.ps1 from this client's own Spell.dbc. Do not edit by hand:");
    sb.AppendLine("-- change the list in that script and run it again.");
    sb.AppendLine("OctoArenaFrames = {}");
    sb.AppendLine("local A = OctoArenaFrames");
    sb.AppendLine("A.SPELLS = {");
    var ids = new SortedDictionary<int,string>();
    var rankcd = new SortedDictionary<int,double>();
    var curatedNames = new HashSet<string>();
    var trig = new List<string>();
    int count = 0;
    foreach (var line0 in curated.Split('\n')) {
      string line = line0.Trim(); if (line=="") continue;
      var f = line.Split('|');
      string cls=f[0], name=f[1], kind=f[2], tier=f[3], flags=f.Length>4?f[4]:"";
      curatedNames.Add(name);
      bool isT = flags.Contains("T") && !flags.Contains("cd="), isP = flags.Contains("P") && !flags.Contains("cd=");
      int cdOverride = 0; var only = new List<int>(); string iconOverride = null;
      foreach (var fl in flags.Split(',')) {
        if (fl.StartsWith("cd=")) cdOverride = int.Parse(fl.Substring(3));
        if (fl.StartsWith("icon=")) iconOverride = fl.Substring(5);
        if (fl.StartsWith("id=")) foreach (var x in fl.Substring(3).Split(';')) only.Add(int.Parse(x));
      }
      // which spell rows are this class's spell of that name
      var rows = new List<int>();
      if (only.Count>0) { foreach (var id in only) rows.Add(id); }
      else {
        List<int> l; if (!byName.TryGetValue(name,out l)) { warn.Add("NOT IN THE GAME: "+line); continue; }
        // 1st choice: spells this class can learn (skill line + family or class mask)
        foreach (var id in l) {
          int rr=row[id];
          if (cls.StartsWith("RACE:")) { if (learnable.Contains(id)) rows.Add(id); continue; }
          if (!learnable.Contains(id)) continue;
          int fam=spell.I(rr,FAM);
          int cm; bool lc = learnClass.TryGetValue(id,out cm) && (cm & classBit[cls])!=0;
          if (lc || fam==classFam[cls]) rows.Add(id);
        }
        // 2nd: talent abilities with no family (Adrenaline Rush, Preparation) - not pets'
        if (rows.Count==0 && !cls.StartsWith("RACE:")) foreach (var id in l) {
          int rr=row[id];
          if (learnable.Contains(id) && spell.I(rr,FAM)==0 && !learnClass.ContainsKey(id) && talentTab.ContainsKey(id)) rows.Add(id);
        }
        // 3rd: the same, on no talent tab
        if (rows.Count==0 && !cls.StartsWith("RACE:")) foreach (var id in l) {
          int rr=row[id];
          if (learnable.Contains(id) && spell.I(rr,FAM)==0 && !learnClass.ContainsKey(id)) rows.Add(id);
        }
        // 4th: the class family with a cooldown (abilities not on a skill line)
        if (rows.Count==0 && !cls.StartsWith("RACE:")) foreach (var id in l) {
          int rr=row[id];
          if (spell.I(rr,FAM)==classFam[cls] && Cd(rr)>0) rows.Add(id);
        }
      }
      rows = rows.Where(id => row.ContainsKey(id) && !spell.S(row[id],DESC).StartsWith("Teaches")).ToList();
      // keep the ranks that have the highest cooldown row data
      if (rows.Count==0) { warn.Add("NO ROWS: "+line); continue; }
      rows.Sort();
      int top = rows.OrderByDescending(id => Cd(row[id])>0?1:0).ThenByDescending(id => DurOf(row[id])>0?0:0).ThenByDescending(id => id).First();
      // highest rank with a cooldown wins
      var withCd = rows.Where(id => Cd(row[id])>0).ToList();
      if (withCd.Count>0) top = withCd.Max();
      int tr = row[top];
      int cd = cdOverride>0 ? cdOverride*1000 : Cd(tr);
      if (cd<=0) warn.Add("NO COOLDOWN: "+line+" id="+top);
      int cat = spell.I(tr,CAT), crec = spell.I(tr,CREC), d = DurOf(tr);
      // interrupts: lockout = the duration of the row with the interrupt effect
      int lockMs = 0;
      for (int e=0;e<3;e++) {
        int ef = spell.I(tr,EFF+e);
        if (ef==68) lockMs = d;
        if (ef==64) { int t=spell.I(tr,TRIG+e); int r2; if (row.TryGetValue(t,out r2)) for (int e2=0;e2<3;e2++) if (spell.I(r2,EFF+e2)==68) { lockMs = DurOf(r2); } }
      }
      string tname=null;
      foreach (var id in rows) { string tn; if (talentTab.TryGetValue(id,out tn)) tname=tn; }
      bool wa = (spell.I(tr,ATTR) & 0x02000000)!=0;
      // the shortest it can be with talents
      int minCd = cd, fam2 = spell.I(tr,FAM), ff = spell.I(tr,FF);
      foreach (var m in mods) {
        if (m[0]==fam2 && m[1]!=0 && (m[1]&ff)!=0) {
          int c = m[3]==1 ? cd+cd*m[2]/100 : cd+m[2];
          if (c<minCd && c>0) minCd = c;
        }
      }
      string icon; iconName.TryGetValue(spell.I(tr,ICON),out icon);
      if (iconOverride!=null) icon = iconOverride;
      if (string.IsNullOrEmpty(icon)) warn.Add("NO ICON: "+line);
      int t2 = tier=="pin"?1:tier=="on"?2:0;
      var e0 = new StringBuilder();
      e0.Append("  {n=\""+Q(name)+"\",c=\""+cls+"\",k=\""+kind+"\",t="+t2+",cd="+Sec(cd));
      if (cat>0 && crec>0 && cdOverride==0) e0.Append(",g="+cat+",gcd="+Sec(crec));
      e0.Append(",i=\""+icon+"\",sc="+spell.I(tr,SCHOOL));
      if (d>0) e0.Append(",d="+Sec(d));
      if (d<0) e0.Append(",d=0");
      if (lockMs>0) e0.Append(",lock="+Sec(lockMs));
      if (wa) e0.Append(",wa=1");
      if (isT||tname!=null) e0.Append(",tal="+(isT?"1":"nil"));
      if (tname!=null) e0.Append(",tab=\""+Q(tname)+"\"");
      if (isP) e0.Append(",pet=1");
      if (minCd<cd) e0.Append(",min="+Sec(minCd));
      e0.Append("},");
      sb.AppendLine(e0.ToString());
      foreach (var id in rows) {
        ids[id]=name;
        int c2 = cdOverride>0?cd:Cd(row[id]);
        if (c2>0 && c2!=cd) rankcd[id]=c2/1000.0;
      }
      count++;
      rv.AppendLine(cls+" | "+name+" | "+kind+"/"+tier+" | cd="+Sec(cd)+(minCd<cd?" min="+Sec(minCd):"")+" cat="+cat+" dur="+Sec(d)+(lockMs>0?" LOCK="+Sec(lockMs):"")+(wa?" WA":"")+" tab="+tname+" ranks="+rows.Count+" top="+top+" | "+Trunc(spell.S(tr,DESC)));
    }
    sb.AppendLine("}");
    sb.AppendLine("A.IDS = {");
    var line2 = new StringBuilder("  ");
    foreach (var kv in ids) { line2.Append("["+kv.Key+"]=\""+Q(kv.Value)+"\","); if (line2.Length>110) { sb.AppendLine(line2.ToString()); line2 = new StringBuilder("  "); } }
    sb.AppendLine(line2.ToString()); sb.AppendLine("}");
    sb.AppendLine("A.RANKCD = {");
    line2 = new StringBuilder("  ");
    foreach (var kv in rankcd) { line2.Append("["+kv.Key+"]="+kv.Value.ToString(System.Globalization.CultureInfo.InvariantCulture)+","); if (line2.Length>110) { sb.AppendLine(line2.ToString()); line2 = new StringBuilder("  "); } }
    sb.AppendLine(line2.ToString()); sb.AppendLine("}");

    // auras: crowd control by mechanic + aura type, for every class-family spell and the extra names
    var extraSet = new HashSet<string>(extra);
    var auras = new SortedDictionary<int,string>();
    for (int r=0;r<spell.Records;r++) {
      int id=spell.I(r,0); int fam=spell.I(r,FAM); string n=spell.S(r,NAME);
      if (id>=65000) continue;
      bool isClass = fam>=3 && fam<=11;
      if (!isClass && !extraSet.Contains(n)) continue;
      int d=DurOf(r); if (d<=0) continue;
      string cat=null;
      for (int e=0;e<3 && cat==null;e++) {
        int au=spell.I(r,AURA+e); int m=spell.I(r,EFFMECH+e); if (m==0) m=spell.I(r,MECH);
        if (au==0) continue;
        if (au==12) cat = (m==14||m==17||m==30) ? "incap" : m==2 ? "disorient" : (m==10||m==13) ? "sleep" : m==18 ? "banish" : "stun";
        else if (au==7) cat = m==24 ? "horror" : (m==5||m==0) ? ((fam==5 && n=="Death Coil")?"horror":"fear") : "fear";
        else if (au==5) cat = m==2 ? "disorient" : (m==10||m==13) ? "sleep" : "incap";
        else if (au==6) cat = "charm";
        else if (au==26) cat = "root";
        else if (au==27) cat = "silence";
      }
      if (cat==null) continue;
      if (spell.I(r,ATTR)==0 && false) continue;
      string desc=spell.S(r,DESC);
      if (curatedNames.Contains(n) && (n=="Ice Block"||n=="Cyclone")) continue;
      string icon; iconName.TryGetValue(spell.I(r,ICON),out icon);
      // combo point spells: the table only has the 1 point length, so no timer for them
      bool combo = n=="Kidney Shot";
      auras[id]="{n=\""+Q(n)+"\",k=\""+cat+"\",d="+(combo?"0":Sec(d))+",i=\""+icon+"\"}";
    }
    // buffs worth showing: the curated cooldowns that leave an aura
    var buffKinds = new[]{"immune","defense","offense","mobility"};
    foreach (var line0 in curated.Split('\n')) {
      string line=line0.Trim(); if (line=="") continue;
      var f=line.Split('|'); string name=f[1], kind=f[2], tier=f[3];
      if (Array.IndexOf(buffKinds,kind)<0) continue;
      foreach (var kv in ids.Where(x=>x.Value==name)) {
        int r=row.ContainsKey(kv.Key)?row[kv.Key]:-1; if (r<0) continue;
        int d=DurOf(r); if (d==0) continue;
        if (d>0 && d<1000) continue;    // effects that are gone at once (Insignia dispels and is done)
        bool hasAura=false; for (int e=0;e<3;e++) if (spell.I(r,AURA+e)!=0) hasAura=true;
        if (!hasAura) continue;
        string icon; iconName.TryGetValue(spell.I(r,ICON),out icon);
        auras[kv.Key]="{n=\""+Q(name)+"\",k=\""+kind+"\",d="+(d<0?"0":Sec(d))+",i=\""+icon+"\"}";
      }
    }
    sb.AppendLine("A.AURAS = {");
    foreach (var kv in auras) sb.AppendLine("  ["+kv.Key+"]="+kv.Value+",");
    sb.AppendLine("}");

    // casts with a cast time, by name: cast time of the highest rank, school, icon, can it be interrupted
    var castNames = new SortedDictionary<string,string>();
    for (int r=0;r<spell.Records;r++) {
      int id=spell.I(r,0); int fam=spell.I(r,FAM);
      if (!classSkill.Contains(id) && !(fam>=3&&fam<=11)) continue;
      int c; castMs.TryGetValue(spell.I(r,CASTIDX),out c);
      string n=spell.S(r,NAME); if (n=="") continue;
      if (spell.S(r,RANK).Contains("Passive")) continue;
      bool channel=(spell.I(r,7)&0x44)!=0;   // AttributesEx channeled bits
      int d=DurOf(r);
      if (c<=0 && !channel) continue;
      if (c>60000) continue;
      string icon; iconName.TryGetValue(spell.I(r,ICON),out icon);
      bool noint=(spell.I(r,INTFLAGS)&4)==0 && !channel;
      string val="{t="+(channel?d:c)+",s="+spell.I(r,SCHOOL)+",i=\""+icon+"\""+(channel?",ch=1":"")+(noint?",ni=1":"")+"}";
      castNames[n]=val;
    }
    sb.AppendLine("A.CASTS = {");
    foreach (var kv in castNames) sb.AppendLine("  [\""+Q(kv.Key)+"\"]="+kv.Value+",");
    sb.AppendLine("}");

    File.WriteAllText(outPath, sb.ToString().Replace("\r\n","\n"));
    if (!string.IsNullOrEmpty(reviewPath)) {
      foreach (var w in warn) rv.Insert(0, "WARN "+w+"\n");
      File.WriteAllText(reviewPath, rv.ToString());
    }
    return "spells "+count+", ids "+ids.Count+", auras "+auras.Count+", casts "+castNames.Count+", warnings "+warn.Count+", talent mods "+mods.Count;
  }
  static string Trunc(string s) { s=s.Replace("\n"," ").Replace("\r",""); return s.Length>120?s.Substring(0,120):s; }
}
"@
Add-Type -TypeDefinition $src -ReferencedAssemblies System.Core
$dir = Split-Path $Out -Parent
if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force $dir | Out-Null }
[Build]::Run($Dbc, ($curated -replace "`r",""), [string[]]$extraAuras, (Resolve-Path $dir).Path + "\" + (Split-Path $Out -Leaf), $Review)
