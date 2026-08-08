import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Memorize Me 사용 가이드",
  description: "Google 시트 가져오기부터 복습, 통계, AI 문제 생성과 PDF 내보내기까지 설명하는 Memorize Me 사용 가이드.",
};

type ManualFigureProps = {
  src: string;
  alt: string;
  caption: string;
  className?: string;
};

function ManualFigure({ src, alt, caption, className = "" }: ManualFigureProps) {
  return (
    <figure className={`manual-figure ${className}`.trim()}>
      <div className="manual-image-wrap">
        <img src={`/media/manual/${src}`} alt={alt} loading="lazy" />
      </div>
      <figcaption>{caption}</figcaption>
    </figure>
  );
}

function Step({ number, title, children }: { number: string; title: string; children: React.ReactNode }) {
  return (
    <li className="manual-step">
      <span className="manual-step-number">{number}</span>
      <div>
        <h3>{title}</h3>
        <p>{children}</p>
      </div>
    </li>
  );
}

export default function ManualPage() {
  return (
    <main className="manual-page" id="manual-top">
      <header className="manual-topbar">
        <a className="brand" href="/" aria-label="Memorize Me 제품 소개로 이동">
          <span className="brand-mark" aria-hidden="true"><span /></span>
          <span>Memorize Me</span>
        </a>
        <nav aria-label="매뉴얼 메뉴">
          <a href="/">제품 소개</a>
          <a href="#ai-guide">AI 학습</a>
          <a className="manual-nav-current" href="#quick-start">사용 가이드</a>
        </nav>
      </header>

      <section className="manual-hero">
        <div className="manual-hero-copy">
          <p className="eyebrow">PRODUCT HANDBOOK · 2026</p>
          <h1>처음부터,<br />막히는 곳까지.</h1>
          <p>
            Google 시트로 단어장을 만드는 첫 순간부터 복습, 퀴즈, 통계와 AI 시험지
            내보내기까지 실제 화면 순서대로 정리했습니다.
          </p>
          <div className="manual-hero-links">
            <a href="#quick-start">처음 사용하는 경우 <span aria-hidden="true">↓</span></a>
            <a href="#ai-guide">AI 학습 설정 <span aria-hidden="true">↓</span></a>
          </div>
        </div>
        <figure className="manual-hero-image">
          <img src="/media/manual/onboarding-start.jpg" alt="Google Sheet에서 단어 학습을 시작하는 온보딩 화면" />
          <figcaption>앱을 처음 열면 핵심 흐름을 먼저 소개합니다.</figcaption>
        </figure>
      </section>

      <div className="manual-layout">
        <aside className="manual-sidebar" aria-label="사용 가이드 목차">
          <p>사용 가이드</p>
          <ol>
            <li><a href="#quick-start"><span>01</span>첫 실행</a></li>
            <li><a href="#import"><span>02</span>단어장 가져오기</a></li>
            <li><a href="#study"><span>03</span>학습과 복습</a></li>
            <li><a href="#statistics"><span>04</span>통계 읽기</a></li>
            <li><a href="#ai-guide"><span>05</span>AI 학습 Beta</a></li>
            <li><a href="#settings"><span>06</span>설정과 도움말</a></li>
            <li><a href="#troubleshooting"><span>07</span>문제 해결</a></li>
          </ol>
          <div className="manual-sidebar-note">
            <strong>AI 기능은 Beta</strong>
            <span>생성 결과는 사용 전 직접 확인해야 합니다.</span>
          </div>
        </aside>

        <article className="manual-content">
          <section className="manual-chapter" id="quick-start">
            <header className="manual-chapter-heading">
              <span>01</span>
              <div>
                <p>FIRST OPEN</p>
                <h2>첫 실행은 기능을 훑고 끝냅니다</h2>
                <p>온보딩은 네 장면으로 구성됩니다. 건너뛰어도 설정에서 언제든 다시 볼 수 있습니다.</p>
              </div>
            </header>

            <div className="manual-onboarding-strip" aria-label="온보딩 화면 미리보기">
              <ManualFigure src="onboarding-start.jpg" alt="Google Sheet 가져오기 온보딩" caption="Google Sheet에서 시작" />
              <ManualFigure src="onboarding-flashcard.jpg" alt="플래시카드 온보딩" caption="카드로 먼저 익히기" />
              <ManualFigure src="onboarding-stats.jpg" alt="통계 온보딩" caption="기억 상태 확인" />
              <ManualFigure src="onboarding-finish.jpg" alt="온보딩 완료 화면" caption="시작하기" />
            </div>

            <ol className="manual-steps">
              <Step number="1" title="핵심 기능을 넘겨봅니다">Google 시트, 플래시카드, 복습과 통계, AI 학습의 역할을 짧게 확인합니다.</Step>
              <Step number="2" title="시작하기를 누릅니다">Google 로그인 후 단어장 관리 화면에서 첫 단어장을 만들 수 있습니다.</Step>
              <Step number="3" title="다시 보고 싶을 때">설정의 ‘온보딩 다시 보기’를 누르면 처음부터 다시 열립니다.</Step>
            </ol>
          </section>

          <section className="manual-chapter" id="import">
            <header className="manual-chapter-heading">
              <span>02</span>
              <div>
                <p>BUILD YOUR WORD BOOK</p>
                <h2>Google 시트를 단어장으로 가져오기</h2>
                <p>앱은 사용자가 Picker에서 직접 고른 스프레드시트만 불러옵니다. CSV 파일도 같은 화면에서 가져올 수 있습니다.</p>
              </div>
            </header>

            <div className="manual-spread manual-spread-wide">
              <div>
                <ol className="manual-steps manual-steps-compact">
                  <Step number="1" title="단어장 관리로 이동">‘Google 시트에서 가져오기’를 누릅니다.</Step>
                  <Step number="2" title="Drive에서 파일 선택">Google 파일 선택기에서 원하는 스프레드시트를 직접 고릅니다.</Step>
                  <Step number="3" title="학습할 시트 선택">파일 안의 시트 목록에서 하나 이상을 체크하고 가져오기를 누릅니다.</Step>
                  <Step number="4" title="활성 단어장 확인">목록에 추가된 단어장에서 ‘이 단어장 사용’을 선택합니다.</Step>
                </ol>
                <div className="manual-note">
                  <strong>목록이 비어 있다면</strong>
                  <span>Drive 전체 파일이 자동으로 보이는 방식이 아닙니다. Picker에서 파일을 한 번 직접 선택해야 합니다.</span>
                </div>
              </div>
              <ManualFigure src="import-entry.jpg" alt="단어장 관리의 Google 시트 가져오기 버튼" caption="단어장 관리 · 가져오기 진입" className="manual-figure-large" />
            </div>

            <div className="manual-gallery manual-gallery-three">
              <ManualFigure src="drive-picker.jpg" alt="Google Drive 파일 선택기" caption="1. 스프레드시트 선택" />
              <ManualFigure src="sheet-select.jpg" alt="가져올 시트 선택 화면" caption="2. 파일 안의 시트 선택" />
              <ManualFigure src="import-complete.jpg" alt="가져오기가 끝난 단어장 목록" caption="3. 단어장 활성화" />
            </div>
          </section>

          <section className="manual-chapter" id="study">
            <header className="manual-chapter-heading">
              <span>03</span>
              <div>
                <p>DAILY STUDY</p>
                <h2>홈에서는 오늘 할 일만 봅니다</h2>
                <p>복습일이 된 단어, 새 단어, 학습 중인 단어가 나뉘어 표시됩니다. 큰 시작 버튼은 가장 먼저 해야 할 학습을 안내합니다.</p>
              </div>
            </header>

            <div className="manual-spread">
              <ManualFigure src="home-overview.jpg" alt="오늘 학습과 단어장 현황이 보이는 홈 화면" caption="오늘 학습 · 현재 단어장" className="manual-figure-large" />
              <div className="manual-copy-block">
                <h3>숫자는 이렇게 읽습니다</h3>
                <dl className="manual-definition-list">
                  <div><dt>복습</dt><dd>복습 예정일이 되어 오늘 다시 볼 단어</dd></div>
                  <div><dt>새 단어</dt><dd>아직 학습을 시작하지 않은 단어</dd></div>
                  <div><dt>학습 중</dt><dd>기억 단계가 올라가는 중인 단어</dd></div>
                  <div><dt>안정 기억</dt><dd>긴 간격으로 복습해도 되는 단계의 단어</dd></div>
                </dl>
                <p className="manual-caption-copy">복습할 단어가 있으면 새 단어보다 복습이 먼저 제안됩니다.</p>
              </div>
            </div>

            <div className="manual-subchapter">
              <p className="eyebrow">FLASHCARDS</p>
              <h3>앞면에서 떠올리고, 뒷면에서 판단합니다</h3>
              <div className="manual-gallery manual-gallery-two">
                <ManualFigure src="flashcard-front.jpg" alt="플래시카드 앞면" caption="단어와 예문, 발음을 먼저 확인" />
                <ManualFigure src="flashcard-back.jpg" alt="플래시카드 뒷면" caption="뜻을 확인하고 몰라요·알아요 기록" />
              </div>
            </div>

            <div className="manual-subchapter">
              <p className="eyebrow">RECALL</p>
              <h3>같은 단어를 다른 방식으로 다시 꺼냅니다</h3>
              <div className="manual-spread manual-spread-reverse">
                <div className="manual-copy-block">
                  <p>복습 탭에서는 플래시카드, 객관식·스펠링 셀프 테스트, 오답 재확인을 선택할 수 있습니다.</p>
                  <ul className="manual-check-list">
                    <li>객관식: 뜻을 빠르게 구분</li>
                    <li>스펠링: 철자를 직접 입력</li>
                    <li>오답 재확인: 틀린 단어만 다시 복습</li>
                  </ul>
                </div>
                <ManualFigure src="review-home.jpg" alt="복습 탭의 학습 방식 목록" caption="복습 탭 · 학습 방식 선택" className="manual-figure-large" />
              </div>
              <div className="manual-gallery manual-gallery-three">
                <ManualFigure src="quiz-multiple-choice.jpg" alt="객관식 퀴즈" caption="객관식" />
                <ManualFigure src="quiz-spelling.jpg" alt="스펠링 퀴즈" caption="스펠링" />
                <ManualFigure src="quiz-feedback.jpg" alt="오답 피드백" caption="오답 피드백" />
              </div>
            </div>
          </section>

          <section className="manual-chapter" id="statistics">
            <header className="manual-chapter-heading">
              <span>04</span>
              <div>
                <p>READ THE SIGNAL</p>
                <h2>통계는 점수가 아니라 기억 상태입니다</h2>
                <p>전체 암기율은 안정 기억 단계에 도달한 단어의 비율입니다. SRS 학습 현황에서는 복습 일정과 단계 분포를 더 자세히 봅니다.</p>
              </div>
            </header>
            <div className="manual-spread">
              <ManualFigure src="stats-overview.jpg" alt="전체 암기율과 SRS 학습 현황" caption="통계 탭 · 전체 암기율" className="manual-figure-large" />
              <div className="manual-copy-block manual-rule-block">
                <span>0%</span>
                <h3>처음에는 0%가 정상입니다</h3>
                <p>새로 가져온 단어는 아직 안정 기억 단계가 아니므로 암기율이 0%로 시작합니다. 학습과 복습을 거치며 단계가 오르면 비율도 함께 바뀝니다.</p>
              </div>
            </div>
          </section>

          <section className="manual-chapter manual-ai-chapter" id="ai-guide">
            <header className="manual-chapter-heading">
              <span>05</span>
              <div>
                <p>AI LEARNING · BETA</p>
                <h2>AI 학습은 설정부터 천천히</h2>
                <p>AI 기능은 사용자의 API 키로 외부 AI 제공자에 요청하는 베타 기능입니다. 아래 순서대로 연결을 확인한 뒤 문제를 생성하세요.</p>
              </div>
            </header>

            <div className="manual-beta-notice">
              <div className="manual-beta-label">BETA</div>
              <div>
                <h3>생성된 문제와 해설은 반드시 확인하세요</h3>
                <p>선택한 단어, 뜻, 예문, 문법 범위와 생성 옵션이 선택한 외부 AI 제공자에게 전송됩니다. AI는 틀린 정답이나 부자연스러운 문장을 만들 수 있습니다.</p>
              </div>
            </div>

            <div className="manual-ai-intro-grid">
              <ManualFigure src="ai-home.jpg" alt="AI 학습 탭 메인 화면" caption="AI 학습 탭 · 생성 기능 선택" />
              <div className="manual-copy-block">
                <h3>시작하기 전에 필요한 것</h3>
                <ul className="manual-check-list">
                  <li>지원되는 AI 제공자의 개인 API 키</li>
                  <li>사용 가능한 모델과 남은 무료·유료 할당량</li>
                  <li>AI에 보낼 단어장과 생성 범위</li>
                </ul>
                <p className="manual-caption-copy">API 키는 앱의 기기 보안 저장소에 보관됩니다. 키를 화면 공유, 캡처, 문의 글에 노출하지 마세요.</p>
              </div>
            </div>

            <div className="manual-subchapter manual-ai-setup">
              <p className="eyebrow">SETUP · 1</p>
              <h3>제공자와 모델을 선택합니다</h3>
              <ol className="manual-steps manual-steps-compact">
                <Step number="1" title="설정에서 AI 모델과 API 열기">접혀 있는 항목을 펼치면 제공자, 모델, API 키와 자동 대체 설정이 나타납니다.</Step>
                <Step number="2" title="AI 회사 선택">Google Gemini, Groq 또는 Custom OpenAI Compatible 중 사용할 제공자를 선택합니다.</Step>
                <Step number="3" title="모델 선택">현재 제공자가 실제로 지원하는 모델을 고릅니다. 무료 표시는 제공자의 정책에 따라 달라질 수 있습니다.</Step>
              </ol>
              <div className="manual-gallery manual-gallery-two">
                <ManualFigure src="ai-settings.jpg" alt="AI 설정 영역" caption="AI 설정을 펼친 화면" />
                <ManualFigure src="ai-provider.jpg" alt="AI 제공자 선택 드롭다운" caption="AI 회사와 모델 선택" />
              </div>
            </div>

            <div className="manual-subchapter manual-ai-setup">
              <p className="eyebrow">SETUP · 2</p>
              <h3>API 키를 등록하고 연결을 확인합니다</h3>
              <div className="manual-spread">
                <ManualFigure src="ai-api-key.jpg" alt="Google Gemini API 키 등록 화면" caption="API 키 입력 · 문자는 가려서 표시" className="manual-figure-large" />
                <div>
                  <ol className="manual-steps manual-steps-compact">
                    <Step number="1" title="관리 버튼을 누릅니다">선택한 제공자의 API 키 입력 창을 엽니다.</Step>
                    <Step number="2" title="키를 붙여넣고 저장합니다">앞뒤 공백이 들어가지 않도록 주의합니다.</Step>
                    <Step number="3" title="현재 AI 설정 연결 테스트">성공 메시지가 나타나는지 확인합니다.</Step>
                  </ol>
                  <div className="manual-note manual-note-warning">
                    <strong>실패하면 먼저 볼 것</strong>
                    <span>키의 유효성, 모델 이름, 제공자 선택, 사용량 제한을 확인하세요. 폐기된 모델은 올바른 키가 있어도 연결되지 않습니다.</span>
                  </div>
                </div>
              </div>
              <div className="manual-gallery manual-gallery-two manual-gallery-short">
                <ManualFigure src="ai-connect-success.jpg" alt="AI 연결 테스트 성공 화면" caption="연결 성공" />
                <ManualFigure src="ai-connect-failure.jpg" alt="AI 연결 테스트 실패 화면" caption="연결 실패 · 오류 메시지 확인" />
              </div>
            </div>

            <div className="manual-subchapter manual-ai-setup">
              <p className="eyebrow">ADVANCED</p>
              <h3>Custom endpoint와 자동 대체</h3>
              <div className="manual-gallery manual-gallery-two">
                <ManualFigure src="ai-endpoint.jpg" alt="Custom OpenAI Compatible endpoint 입력" caption="OpenAI 호환 endpoint 직접 입력" />
                <ManualFigure src="ai-fallback.jpg" alt="AI 자동 대체 순서 설정" caption="오류 시 이어서 시도할 후보 순서" />
              </div>
              <div className="manual-two-column-copy">
                <div><strong>Custom endpoint</strong><p>기본 목록에 없는 OpenAI 호환 서비스를 사용할 때만 입력합니다. Chat Completions 또는 Responses endpoint 형식이 서비스 문서와 일치해야 합니다.</p></div>
                <div><strong>자동 대체</strong><p>첫 제공자가 실패하면 체크한 후보를 위에서 아래 순서로 시도합니다. 후보마다 별도의 유효한 API 키가 필요할 수 있습니다.</p></div>
              </div>
            </div>

            <div className="manual-subchapter">
              <p className="eyebrow">GENERATE</p>
              <h3>단어를 고르고 문제를 생성합니다</h3>
              <ol className="manual-steps manual-steps-horizontal">
                <Step number="1" title="퀴즈 생성 진입">현재 단어장에서 출제할 단어를 선택합니다.</Step>
                <Step number="2" title="옵션 설정">언어, 유형, 난이도, 문제 수와 해설 포함 여부를 정합니다.</Step>
                <Step number="3" title="결과 검토">생성된 문항과 정답, 해설을 확인한 후 사용합니다.</Step>
              </ol>
              <div className="manual-gallery manual-gallery-four">
                <ManualFigure src="ai-quiz-entry.jpg" alt="AI 퀴즈 생성 진입 화면" caption="출제 단어 선택" />
                <ManualFigure src="ai-quiz-options.jpg" alt="AI 퀴즈 옵션 화면" caption="퀴즈 옵션" />
                <ManualFigure src="ai-generating.jpg" alt="AI 생성 중 화면" caption="생성 중" />
                <ManualFigure src="ai-result.jpg" alt="AI 퀴즈 생성 결과" caption="문항 검토" />
              </div>
              <div className="manual-note">
                <strong>요청한 수보다 적게 생성될 수 있습니다</strong>
                <span>중복되거나 형식이 맞지 않는 문항은 제외됩니다. 남은 문항으로 계속하거나 수를 줄여 다시 생성하세요.</span>
              </div>
            </div>

            <div className="manual-subchapter">
              <p className="eyebrow">EXPORT</p>
              <h3>문제는 PDF 또는 HTML로 내보냅니다</h3>
              <div className="manual-gallery manual-gallery-four">
                <ManualFigure src="pdf-result.jpg" alt="AI 결과의 PDF 내보내기 버튼" caption="내보내기 열기" />
                <ManualFigure src="pdf-dialog.jpg" alt="PDF 제목 입력 다이얼로그" caption="파일 제목 입력" />
                <ManualFigure src="pdf-options.jpg" alt="문제와 정답 또는 문제만 선택" caption="정답 포함 여부 선택" />
                <ManualFigure src="share-sheet.jpg" alt="Android 공유 시트" caption="저장하거나 다른 앱으로 공유" />
              </div>
            </div>
          </section>

          <section className="manual-chapter" id="settings">
            <header className="manual-chapter-heading">
              <span>06</span>
              <div>
                <p>SETTINGS</p>
                <h2>화면과 도움말은 설정에서 관리합니다</h2>
                <p>기본 밝음, 어두운 테마, 시력 보호 모드 중 하나를 선택합니다. 시력 보호 모드에서는 배경 농도를 별도로 조절할 수 있습니다.</p>
              </div>
            </header>
            <div className="manual-gallery manual-gallery-two">
              <ManualFigure src="eye-comfort.jpg" alt="시력 보호 모드와 배경 농도 설정" caption="디자인 · 시력 보호 농도" />
              <ManualFigure src="settings-guide.jpg" alt="설정의 사용 가이드와 온보딩 다시 보기" caption="가이드 · 온보딩 다시 보기" />
            </div>
          </section>

          <section className="manual-chapter" id="troubleshooting">
            <header className="manual-chapter-heading">
              <span>07</span>
              <div>
                <p>TROUBLESHOOTING</p>
                <h2>자주 막히는 지점</h2>
                <p>오류 문구를 먼저 확인하고 아래 순서대로 점검하세요.</p>
              </div>
            </header>

            <div className="manual-troubleshooting">
              <details open>
                <summary>Google Drive 파일 선택기가 설정되지 않았다고 나옵니다</summary>
                <p>배포 빌드에 Google Picker 웹 URL이 포함되지 않은 상태입니다. 앱 개발자가 Picker 호스팅 URL을 빌드 설정에 포함한 버전을 설치해야 합니다.</p>
              </details>
              <details>
                <summary>선택한 스프레드시트가 목록에 없습니다</summary>
                <p>이 앱은 Drive 전체 목록을 읽지 않습니다. Google Picker를 다시 열고 해당 파일을 직접 선택한 뒤 시트 목록에서 가져오세요.</p>
              </details>
              <details>
                <summary>Google 로그인이 되지 않습니다</summary>
                <p>인터넷 연결과 Google 계정을 확인합니다. 테스트 버전이라면 OAuth 테스트 사용자 등록 여부, 배포 버전이라면 패키지명과 SHA 인증서 지문 구성이 맞아야 합니다.</p>
              </details>
              <details>
                <summary>AI 연결 테스트가 실패합니다</summary>
                <p>API 키, 제공자, 모델 이름, endpoint, 사용량 제한을 순서대로 확인합니다. 모델이 폐기되었거나 무료 할당량이 끝난 경우 다른 지원 모델로 변경하세요.</p>
              </details>
              <details>
                <summary>AI 문제가 일부만 생성됩니다</summary>
                <p>중복 또는 형식 오류 문항이 제외된 결과입니다. 생성된 문항을 먼저 검토하고, 필요한 경우 문제 수를 줄이거나 다른 모델로 다시 시도하세요.</p>
              </details>
            </div>
          </section>

          <section className="manual-end">
            <p>여기까지 읽었다면 준비가 끝났습니다.</p>
            <h2>단어장을 고르고<br />오늘 학습을 시작하세요.</h2>
            <a href="#manual-top">매뉴얼 처음으로 <span aria-hidden="true">↑</span></a>
          </section>
        </article>
      </div>
    </main>
  );
}
