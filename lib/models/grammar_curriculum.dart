class GrammarChapter {
  final String title;
  final String description;
  final List<String> details;

  const GrammarChapter({required this.title, required this.description, required this.details});
}

class GrammarCategory {
  final String title;
  final String description;
  final List<GrammarChapter> chapters;

  const GrammarCategory({required this.title, required this.description, required this.chapters});
}

// 제공해주신 데이터를 바탕으로 한 전체 커리큘럼 정보
const List<GrammarCategory> grammarCurriculum = [
  GrammarCategory(
    title: '중학교 영문법',
    description: '기초 다지기: 영어 문장의 기본 구조를 이해하고, 기초적인 시제와 품사의 활용법을 익힙니다.',
    chapters: [
      GrammarChapter(
        title: '1. 문장의 기초',
        description: '8품사와 문장 성분',
        details: [
          '8품사: 명사, 대명사, 동사, 형용사, 부사, 전치사, 접속사, 감탄사',
          '문장 성분: 주어(S), 동사(V), 목적어(O), 보어(C), 수식어(M)',
        ],
      ),
      GrammarChapter(
        title: '2. 문장의 종류',
        description: '평서문, 의문문, 명령문, 감탄문',
        details: [
          'Be동사/일반동사 의문문',
          'Wh-의문문 (Who, What, When, Where, Why, How)',
          '긍정/부정 명령문',
          '부가 의문문, 간접 의문문',
        ],
      ),
      GrammarChapter(
        title: '3. 시제 (Tenses)',
        description: '현재, 과거, 미래의 표현',
        details: ['단순 시제: 현재, 과거, 미래', '진행 시제: 현재진행, 과거진행', '현재완료 시제의 기본 개념 (경험, 계속, 완료, 결과)'],
      ),
      GrammarChapter(
        title: '4. 동사',
        description: 'Be동사, 일반동사, 조동사',
        details: ['Be동사와 일반동사의 구분 및 활용', '주요 조동사: can, may, must, should, will, would'],
      ),
      GrammarChapter(
        title: '5. to부정사',
        description: '명사적, 형용사적, 부사적 용법',
        details: [
          '명사적 용법: ~하는 것 (주어, 목적어, 보어)',
          '형용사적 용법: ~할 (명사 수식)',
          '부사적 용법: ~하기 위해 (목적), ~해서 (감정의 원인)',
        ],
      ),
      GrammarChapter(
        title: '6. 동명사',
        description: '동사의 명사적 활용',
        details: ['동명사의 역할 (주어, 목적어, 보어)', 'to부정사 vs. 동명사 (목적어로 취하는 동사 구분)'],
      ),
      GrammarChapter(
        title: '7. 분사',
        description: '현재분사와 과거분사',
        details: ['현재분사(~ing)와 과거분사(p.p.)의 기본 개념', '감정 동사의 분사형 (interesting/interested)'],
      ),
      GrammarChapter(
        title: '8. 수동태',
        description: '행위의 대상을 강조하는 표현',
        details: ['수동태의 기본 형태 (be + p.p.)', '3형식, 4형식 문장의 수동태'],
      ),
      GrammarChapter(
        title: '9. 대명사',
        description: '인칭, 지시, 부정 대명사',
        details: [
          '인칭대명사 (주격, 소유격, 목적격)',
          '지시대명사 (this, that, these, those)',
          '부정대명사 (one, some, any, other, another)',
        ],
      ),
      GrammarChapter(
        title: '10. 형용사와 부사',
        description: '명사 수식과 동사/문장 수식',
        details: [
          '형용사의 역할 (명사 수식, 보어)',
          '부사의 역할 (동사, 형용사, 다른 부사, 문장 전체 수식)',
          '비교: 원급, 비교급, 최상급 (as...as, -er/more, -est/most)',
        ],
      ),
      GrammarChapter(
        title: '11. 접속사',
        description: '단어, 구, 절의 연결',
        details: ['등위접속사: and, but, or, so', '종속접속사: that, if, whether, when, because, although'],
      ),
      GrammarChapter(
        title: '12. 관계대명사',
        description: '두 문장을 연결하는 접속사+대명사',
        details: ['주격 관계대명사: who, which, that', '목적격 관계대명사: whom, which, that'],
      ),
      GrammarChapter(
        title: '13. 전치사',
        description: '시간, 장소, 방향',
        details: ['시간 전치사: at, on, in, for, during', '장소/방향 전치사: at, on, in, to, from, into'],
      ),
    ],
  ),
  GrammarCategory(
    title: '고등학교 영문법',
    description: '심화 및 확장: 복잡한 문장 구조를 이해하고, 준동사의 심화 용법 및 특수 구문을 학습합니다.',
    chapters: [
      GrammarChapter(
        title: '1. 문장의 구조 심화',
        description: '5형식 문장의 확장',
        details: ['5형식 동사의 심화 학습 (사역동사, 지각동사)', '목적격 보어로 to부정사, 원형부정사, 분사를 사용하는 경우'],
      ),
      GrammarChapter(
        title: '2. 시제 심화',
        description: '완료 시제 및 시제 일치',
        details: ['완료 시제: 현재완료, 과거완료, 미래완료', '완료 진행 시제: 현재완료진행, 과거완료진행', '주절과 종속절의 시제 일치 및 예외'],
      ),
      GrammarChapter(
        title: '3. 조동사 심화',
        description: '추측, 후회 등의 표현',
        details: [
          'must have p.p., may have p.p., cannot have p.p. (과거 사실에 대한 추측)',
          'should have p.p. (과거 사실에 대한 후회/유감)',
        ],
      ),
      GrammarChapter(
        title: '4. to부정사 심화',
        description: '의미상의 주어, 시제, 태',
        details: [
          'to부정사의 의미상의 주어 (for/of + 목적격)',
          '완료 부정사 (to have p.p.), 수동 부정사 (to be p.p.)',
          '독립 부정사 (관용적 표현)',
        ],
      ),
      GrammarChapter(
        title: '5. 동명사 심화',
        description: '의미상의 주어, 시제, 태',
        details: ['동명사의 의미상의 주어 (소유격/목적격)', '완료 동명사 (having p.p.), 수동 동명사 (being p.p.)'],
      ),
      GrammarChapter(
        title: '6. 분사 심화',
        description: '분사구문',
        details: ['분사구문: 부사절을 분사를 이용해 간결하게 표현 (시간, 이유, 조건, 양보, 동시동작)', 'with + 명사 + 분사 (부대상황)'],
      ),
      GrammarChapter(
        title: '7. 수동태 심화',
        description: '다양한 형태의 수동태',
        details: ['4형식, 5형식 문장의 수동태 심화', '대명령문의 수동태, 동사구의 수동태', 'by 이외의 전치사를 사용하는 수동태'],
      ),
      GrammarChapter(
        title: '8. 관계사 심화',
        description: '관계대명사, 관계부사',
        details: [
          '소유격 관계대명사: whose',
          '관계대명사 what (~하는 것)',
          '관계부사: where, when, why, how',
          '복합 관계사 (-ever): whoever, whatever, whenever, wherever',
        ],
      ),
      GrammarChapter(
        title: '9. 가정법',
        description: '사실과 반대되는 상황 가정',
        details: ['가정법 과거: 현재 사실의 반대', '가정법 과거완료: 과거 사실의 반대', '혼합 가정법, I wish/as if 가정법'],
      ),
      GrammarChapter(
        title: '10. 비교 구문 심화',
        description: '다양한 비교 표현',
        details: [
          'the + 비교급, the + 비교급',
          '배수사 비교 (twice as...as, three times more...than)',
          '비교급을 이용한 최상급 표현',
        ],
      ),
      GrammarChapter(
        title: '11. 특수 구문',
        description: '강조, 도치, 생략, 병렬',
        details: [
          '강조: It...that 강조 구문, do/does/did 강조',
          '도치: 부정어/부사구/보어 도치',
          '생략: 반복을 피하기 위한 생략',
          '병렬 구조',
        ],
      ),
      GrammarChapter(
        title: '12. 접속사 심화',
        description: '다양한 종속접속사 및 상관접속사',
        details: ['명사절/부사절 접속사', '상관접속사: both A and B, either A or B, not only A but also B'],
      ),
    ],
  ),
  GrammarCategory(
    title: '토익(TOEIC) 영문법',
    description: '실용 및 문제 풀이 중심: 비즈니스 및 일상생활에서의 실용성에 초점을 맞추며, 정답을 빠르게 찾는 능력이 중요합니다.',
    chapters: [
      GrammarChapter(
        title: '1. 문장 구조 (파트 5/6 핵심)',
        description: '주어-동사 찾기',
        details: ['수일치', '능동태 vs. 수동태', '시제'],
      ),
      GrammarChapter(
        title: '2. 동사/준동사',
        description: '동사 자리 vs. 준동사 자리 구분',
        details: ['한 문장에 동사는 하나!', 'to부정사', '동명사', '분사'],
      ),
      GrammarChapter(
        title: '3. 품사',
        description: '알맞은 품사 채우기',
        details: ['명사 자리', '형용사 자리', '부사 자리', '특정 형용사/부사 어휘'],
      ),
      GrammarChapter(
        title: '4. 접속사/전치사/부사',
        description: '문맥에 맞는 연결어 선택',
        details: ['접속사 vs. 전치사 구분', '상관접속사'],
      ),
      GrammarChapter(
        title: '5. 관계사',
        description: '선행사와 격에 맞는 관계사',
        details: ['관계대명사 vs. 관계부사', 'that vs. what', '복합관계사'],
      ),
      GrammarChapter(
        title: '6. 대명사',
        description: '격과 수에 맞는 대명사',
        details: ['인칭대명사의 격 구분', '지시대명사 that/those', '부정대명사 one/another/other(s)'],
      ),
      GrammarChapter(
        title: '7. 비교 구문/도치',
        description: '고득점 변별력 문제',
        details: ['원급/비교급/최상급 형태와 수식어', '부정어 도치'],
      ),
    ],
  ),
];
