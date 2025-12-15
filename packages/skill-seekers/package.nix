{
  lib,
  python3,
  fetchFromGitHub,
}:

let
  mcp = python3.pkgs.mcp.overridePythonAttrs (old: rec {
    version = "1.18.0";
    src = fetchFromGitHub {
      owner = "modelcontextprotocol";
      repo = "python-sdk";
      tag = "v${version}";
      hash = "sha256-iOfxZbXqw5J/08NUT9BYSf02BvdLLo6xP/HTtEN/CBM=";
    };
  });
in

python3.pkgs.buildPythonApplication rec {
  pname = "skill-seekers";
  version = "2.1.1";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "yusufkaraaslan";
    repo = "Skill_Seekers";
    rev = "v${version}";
    hash = "sha256-GxFtcqifOmXcTp62yh2nEhDRP0ak6fkNRRIjazslnL0=";
  };

  build-system = [
    python3.pkgs.setuptools
    python3.pkgs.wheel
  ];

  nativeBuildInputs = [
    python3.pkgs.pythonRelaxDepsHook
  ];

  pythonRelaxDeps = [
    "beautifulsoup4"
    "click"
    "jsonschema"
    "pydantic"
    "pydantic-settings"
  ];

  dependencies =
    with python3.pkgs;
    [
      beautifulsoup4
      click
      httpx
      httpx-sse
      jsonschema
    ]
    ++ [
      mcp # Use overridden version from let binding
    ]
    ++ (with python3.pkgs; [
      pillow
      pydantic
      pydantic-settings
      pygithub
      pygments
      pymupdf
      pytesseract
      python-dotenv
      requests
    ]);

  optional-dependencies = {
    all =
      with python3.pkgs;
      [
        coverage
        httpx
        httpx-sse
      ]
      ++ [ mcp ]
      ++ (with python3.pkgs; [
        pytest
        pytest-cov
        sse-starlette
        starlette
        uvicorn
      ]);
    dev = with python3.pkgs; [
      coverage
      pytest
      pytest-cov
    ];
    mcp =
      with python3.pkgs;
      [
        httpx
        httpx-sse
      ]
      ++ [ mcp ]
      ++ (with python3.pkgs; [
        sse-starlette
        starlette
        uvicorn
      ]);
  };

  pythonImportsCheck = [
    "skill_seekers"
  ];

  meta = {
    description = "Convert documentation websites, GitHub repositories, and PDFs into Claude AI skills with automatic conflict detection";
    homepage = "https://github.com/yusufkaraaslan/Skill_Seekers";
    changelog = "https://github.com/yusufkaraaslan/Skill_Seekers/blob/${src.rev}/CHANGELOG.md";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ kolya.ay ];
    mainProgram = "skill-seekers";
  };
}
