#!/usr/bin/env python3
"""
Extract and format questions from Medicoholic NEET-PG text files.
Usage: python3 extract_medicoholic.py <input.txt> <output.md> <year> <start_q_num>
"""

import re, sys
from collections import defaultdict

SUBJECT_ORDER = [
    'Anatomy', 'Physiology', 'Biochemistry', 'Pathology', 'Microbiology',
    'Pharmacology', 'Forensic Medicine', 'Community Medicine',
    'Medicine', 'Surgery', 'Obstetrics & Gynaecology', 'Paediatrics',
    'Orthopaedics', 'ENT', 'Ophthalmology', 'Dermatology',
    'Psychiatry', 'Radiology', 'Anaesthesia',
]

def get_subject(stem, opts_text, q_num):
    t = (stem + ' ' + opts_text).lower()
    if any(k in t for k in ['placent','pregnanc','obstetric','uterus','gynaecolog','amenorrhoea',
                              'menstrual','cervical cancer','ovarian','fallopian','eclampsia',
                              'preeclampsia','partogram','labour','fetal','lactation',
                              'breastfeed','gestational','ectopic pregnancy','fibroid',
                              'hysterectomy','endometrium','perineum','vulva','vagina']):
        return 'Obstetrics & Gynaecology'
    if any(k in t for k in ['nerve root','brachial plexus','embryolog','muscle insertion',
                              'muscle origin','nerve supply','dermatome','myotome',
                              'cavernous sinus','cranial nerve','erb','klumpke',
                              'thoracodorsal','carpal tunnel','femoral canal','inguinal',
                              'scapula','humerus','femur','tibia','cubital fossa',
                              'median nerve','ulnar nerve','radial nerve','axillary nerve',
                              'obturator nerve','peroneal nerve','sciatic nerve']):
        return 'Anatomy'
    if any(k in t for k in ['cardiac output','lung capacity','spirometry','vital capacity',
                              'action potential','resting membrane','renal clearance',
                              'glomerular filtration','aldosterone secretion','renin release',
                              'bohr effect','haemoglobin dissociation','dead space',
                              'tidal volume','baroreceptor','chemoreceptor','fick principle',
                              'starling law','frank-starling']):
        return 'Physiology'
    if any(k in t for k in ['enzyme deficiency','metabolic pathway','vitamin deficiency',
                              'amino acid metabolism','protein synthesis','dna replication',
                              'glycolysis','krebs cycle','fatty acid synthesis','cholesterol',
                              'purine synthesis','pyrimidine','collagen synthesis',
                              'urea cycle','porphyria','phenylketonuria']):
        return 'Biochemistry'
    if any(k in t for k in ['drug of choice','mechanism of action','drug side effect',
                              'pharmacokinetic','bioavailability','half life','agonist',
                              'beta blocker','ace inhibitor','diuretic mechanism',
                              'antibiotic spectrum','antifungal','antiviral mechanism',
                              'idoxuridine','mefloquine','chloroquine','receptor type',
                              'proton pump inhibitor','nsaid','opioid receptor']):
        return 'Pharmacology'
    if any(k in t for k in ['neoplasm','carcinoma cell type','inflammat','cell injury',
                              'histology finding','biopsy finding','amyloid','granuloma',
                              'fibrosis','metaplasia','dysplasia','lymphoma','leukaemia',
                              'infarct type','coagulative necrosis','fibroblast','neoplastic',
                              'medulloblastoma','glioma','astrocytoma','tumour marker',
                              'reed-sternberg','psammoma','apoptosis']):
        return 'Pathology'
    if any(k in t for k in ['bacteria','virus','fungi','parasite','vaccine type',
                              'antigen','culture medium','gram stain','malaria species',
                              'tuberculosis','hepatitis virus','herpes','staphylococcus',
                              'streptococcus','e. coli','salmonella','shigella','clostridium',
                              'bacillus cereus','incubation period','serology','elisa',
                              'ppd test','widal test']):
        return 'Microbiology'
    if any(k in t for k in ['time of death','rigor mortis','putrefaction','poison',
                              'toxicolog','medico-legal','wound type','diatoms',
                              'drowning','hanging','strangulation','burns percentage',
                              'corrosive','irritant poison','organophosphate','carbon monoxide',
                              'miner cramp','heat exhaustion','heat stroke']):
        return 'Forensic Medicine'
    if any(k in t for k in ['epidemiology','incidence','prevalence','sensitivity',
                              'specificity','vaccination schedule','nutritional',
                              'national programme','health indicator','birth rate',
                              'female sterilization','community','immunization',
                              'public health','mortality rate','endemic zone',
                              'catheter infection prevention','surveillance']):
        return 'Community Medicine'
    if any(k in t for k in ['diabetes mellitus','hypertension management','thyroid disease',
                              'nephrology','glomerulonephritis','cardiology finding',
                              'rheumatoid','sle diagnosis','fever management','jaundice type',
                              'hepatic','cirrhosis','pneumonia','tuberculosis treatment',
                              'ecg finding','anaemia type','heart failure','myocardial',
                              'oral ulcer']):
        return 'Medicine'
    if any(k in t for k in ['appendicitis','hernia type','bowel obstruction','peritonitis',
                              'surgical management','thyroid surgery','colostomy','ileostomy',
                              'pancreatitis','cholecystitis','carcinoma stomach','sigmoid']):
        return 'Surgery'
    if any(k in t for k in ['child development','neonatal','infant growth','paediatric',
                              'growth chart','imci','vaccination child','congenital heart',
                              'autism','apgar score','breastfeeding duration','kwashiorkor']):
        return 'Paediatrics'
    if any(k in t for k in ['fracture management','orthopedic','joint replacement',
                              'osteomyelitis','osteoporosis','scoliosis','clubfoot',
                              'osteosarcoma','acl injury','meniscus tear','ligament']):
        return 'Orthopaedics'
    if any(k in t for k in [' ear ',' nose ',' throat ','otitis media','tympanic',
                              'rhinitis','sinusitis','tonsillitis','laryngeal','vocal cord',
                              'nasopharyngeal','epistaxis','nasal polyp','ent ']):
        return 'ENT'
    if any(k in t for k in ['glaucoma','cataract','retina','cornea','optic nerve','visual acuity',
                              'hypermetropia','myopia','strabismus','conjunctivitis',
                              'pseudopapilitis','silk shot appearance','intraocular']):
        return 'Ophthalmology'
    if any(k in t for k in ['skin disease','dermatitis','psoriasis','eczema','scabies',
                              'leprosy','vitiligo','melanoma','bowen','pemphigus','urticaria',
                              'dermatology','tinea','fungal skin','alopecia']):
        return 'Dermatology'
    if any(k in t for k in ['schizophrenia','depression','anxiety disorder','psychosis',
                              'mania','bipolar','lithium therapy','antipsychotic','dementia',
                              'delirium','adhd','trichotillomania','capgras','psychiatric',
                              'phobia','obsessive']):
        return 'Psychiatry'
    if any(k in t for k in ['x-ray finding','ct scan','mri finding','ultrasound','imaging',
                              'radiology','contrast medium','barium','interventional',
                              'radiation dose','pet scan','angiography']):
        return 'Radiology'
    if any(k in t for k in ['anaesthesia','anesthesia','intubation','spinal block',
                              'epidural','propofol','halothane','neuromuscular block',
                              'mallampati','laryngeal mask','induction agent']):
        return 'Anaesthesia'
    # Default by question number range
    if q_num <= 100: return 'Anatomy'
    elif q_num <= 250: return 'Physiology'
    elif q_num <= 450: return 'Biochemistry'
    elif q_num <= 650: return 'Pathology'
    elif q_num <= 800: return 'Pharmacology'
    elif q_num <= 1000: return 'Community Medicine'
    elif q_num <= 1100: return 'ENT'
    elif q_num <= 1200: return 'Ophthalmology'
    elif q_num <= 1400: return 'Medicine'
    elif q_num <= 1500: return 'Surgery'
    elif q_num <= 1600: return 'Psychiatry'
    else: return 'Dermatology'


def clean_option(text):
    text = re.sub(r'\s+', ' ', text).strip()
    return text


def clean_stem(stem):
    """Fix common OCR artifacts in stems."""
    # Remove common OCR prefixes from PDF extraction
    stem = re.sub(r'^A\s*roots?\.\s*', '', stem, flags=re.IGNORECASE)
    stem = re.sub(r'^A\s*injection\s*', '', stem, flags=re.IGNORECASE)
    stem = re.sub(r'^A\s*[\d]{1,2}\s*\.?\s*', '', stem)
    # Remove trailing exam year markers like "Jharkhand 10", "March 2007", "September 2005"
    stem = re.sub(r'\s+(Jharkhand|September|March|December|January|June)\s+\d{2,4}\s*(\([a-z]\))?\s*$', '', stem)
    stem = re.sub(r'\s+\d{4}\s*\([a-z]\)\s*$', '', stem)
    # Fix "Which/All of the following" when stem starts with "of the following"
    if re.match(r'^of the following', stem, re.IGNORECASE):
        stem = 'Which ' + stem
    # Remove trailing OCR artifacts
    stem = re.sub(r'\s+[A-Z][a-z]+\s*\d{1,2}\s*$', '', stem)
    stem = re.sub(r'\s+', ' ', stem).strip()
    return stem


def parse_file(filepath):
    with open(filepath, encoding='utf-8', errors='replace') as f:
        content = f.read()
    content = content.replace('\x0c', '')  # remove form-feed
    lines = content.split('\n')

    ca_positions = []
    for i, l in enumerate(lines):
        if re.match(r'^Correct Answer - ([A-D])\s*$', l.strip()):
            ca_positions.append((i, l.strip()[-1]))

    questions = []

    for ca_idx, (ca_pos, ans) in enumerate(ca_positions):
        block_start = ca_positions[ca_idx - 1][0] + 1 if ca_idx > 0 else 0
        block = lines[block_start:ca_pos]
        block_text = '\n'.join(block)

        opt_d = re.search(r'^\s{0,6}d\)\s*(.+?)$', block_text, re.MULTILINE)
        opt_c = re.search(r'^\s{0,6}c\)\s*(.+?)$', block_text, re.MULTILINE)
        opt_b = re.search(r'^\s{0,6}b\)\s*(.+?)$', block_text, re.MULTILINE)
        opt_a = re.search(r'^\s{0,6}a\)\s*(.+?)$', block_text, re.MULTILINE)

        if not all([opt_a, opt_b, opt_c, opt_d]):
            continue

        opt_a_pos = opt_a.start()
        stem_text = block_text[:opt_a_pos].strip()

        # Find last numbered question in stem
        q_matches = list(re.finditer(r'(?:^|\n)\s*(\d+)\.\s+(.+?)(?=\n|$)', stem_text, re.MULTILINE))
        if not q_matches:
            continue

        last_m = q_matches[-1]
        q_num = int(last_m.group(1))
        q_stem_start = last_m.group(2).strip()

        # Get continuation lines
        after_qnum = stem_text[last_m.end():]
        cont_lines = []
        for cl in after_qnum.split('\n'):
            cl = cl.strip()
            if not cl:
                continue
            if re.match(r'^(Ans\.|Ref\.|Answer|Correct|The clinical|This condition|Treatment|Note:|[0-9]+\.|[a-z][ :-])', cl):
                break
            cont_lines.append(cl)

        stem = q_stem_start
        if cont_lines:
            stem += ' ' + ' '.join(cont_lines[:3])  # max 3 continuation lines
        stem = re.sub(r'\s+', ' ', stem).strip()
        stem = clean_stem(stem)

        if len(stem) < 12:
            continue
        if 'Correct Answer' in stem or (stem.startswith('Ans.') or stem.startswith('Ref.')):
            continue
        if any(k in stem.lower() for k in ['shown in figure', 'given image', 'photograph shows']):
            continue

        opts = {
            'A': clean_option(opt_a.group(1)),
            'B': clean_option(opt_b.group(1)),
            'C': clean_option(opt_c.group(1)),
            'D': clean_option(opt_d.group(1)),
        }

        questions.append({'n': q_num, 'stem': stem, **opts, 'answer': ans})

    return questions


def topic_label(stem):
    """Extract a short topic label from the stem."""
    stem = re.sub(r'^(which|what|all|most|the|a|an)\s+', '', stem, flags=re.IGNORECASE)
    # Take first 5 words
    words = stem.split()[:6]
    label = ' '.join(words)
    label = re.sub(r'[^\w\s\-\(\)&]', '', label).strip()
    if len(label) > 50:
        label = label[:47] + '...'
    return label


def format_questions(questions, year, start_q_num, skip_subjects=None, max_per_subject=8):
    """Format questions as Markdown, grouped by subject."""
    skip_subjects = skip_subjects or []

    # Group by subject
    by_subject = defaultdict(list)
    for q in questions:
        subj = get_subject(q['stem'], q['A']+q['B']+q['C']+q['D'], q['n'])
        if subj not in skip_subjects:
            by_subject[subj].append(q)

    # Select questions: up to max_per_subject per subject, spread across number range
    selected = []
    for subj in SUBJECT_ORDER:
        qs = by_subject.get(subj, [])
        if not qs:
            continue
        # Sort by question number
        qs.sort(key=lambda q: q['n'])
        # Pick evenly spaced
        if len(qs) <= max_per_subject:
            picked = qs
        else:
            step = len(qs) / max_per_subject
            picked = [qs[int(i * step)] for i in range(max_per_subject)]
        for q in picked:
            selected.append((subj, q))

    # Generate markdown
    md_parts = []
    cur_subj = None
    q_counter = start_q_num

    for subj, q in selected:
        if subj != cur_subj:
            md_parts.append(f'\n## {subj}\n')
            cur_subj = subj

        label = topic_label(q['stem'])
        ans_letter = q['answer']
        ans_text = q[ans_letter]

        md_parts.append(f'### Q{q_counter} — {label} *({year})*\n')
        md_parts.append(f'{q["stem"]}\n')
        md_parts.append(f'- A. {q["A"]}')
        md_parts.append(f'- B. {q["B"]}')
        md_parts.append(f'- C. {q["C"]}')
        md_parts.append(f'- D. {q["D"]}')
        md_parts.append('')
        md_parts.append('<details><summary>Answer</summary>')
        md_parts.append('')
        md_parts.append(f'**{ans_letter}. {ans_text}**')
        md_parts.append('')
        md_parts.append('</details>')
        md_parts.append('')
        md_parts.append('---')
        md_parts.append('')
        q_counter += 1

    return '\n'.join(md_parts), q_counter - start_q_num


if __name__ == '__main__':
    if len(sys.argv) < 5:
        print("Usage: extract_medicoholic.py <input.txt> <output.md> <year> <start_q_num>")
        sys.exit(1)

    input_file = sys.argv[1]
    output_file = sys.argv[2]
    year = sys.argv[3]
    start_q = int(sys.argv[4])

    print(f"Parsing {input_file}...")
    qs = parse_file(input_file)
    print(f"Parsed {len(qs)} questions")

    # Skip OBG since already added
    skip = ['Obstetrics & Gynaecology']
    if year == '2015':
        skip.append('Anatomy')  # 2015 already has Anatomy Q1-Q12

    md, count = format_questions(qs, year, start_q, skip_subjects=skip, max_per_subject=8)

    with open(output_file, 'a') as f:
        f.write(md)

    print(f"Appended {count} questions to {output_file}")
