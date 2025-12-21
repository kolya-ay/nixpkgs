{
  lib,
  python3,
  fetchFromGitHub,
}:

python3.pkgs.buildPythonApplication rec {
  pname = "basic-memory";
  version = "0.16.3";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "basicmachines-co";
    repo = "basic-memory";
    rev = "v${version}";
    hash = "sha256-9rIb8tVYAsHB0VcY4lJe5fmB1V8TwzXp39cKPrF83D4=";
  };

  build-system = [
    python3.pkgs.hatchling
    python3.pkgs.uv-dynamic-versioning
  ];

  nativeBuildInputs = [
    python3.pkgs.pythonRelaxDepsHook
  ];

  pythonRelaxDeps = true;

  pythonRemoveDeps = [
    "pyright"
    "pytest-aio"
    "pytest-asyncio"
  ];

  dependencies = with python3.pkgs; [
    aiofiles
    aiosqlite
    alembic
    asyncpg
    dateparser
    fastapi
    fastmcp
    greenlet
    loguru
    markdown-it-py
    mcp
    nest-asyncio
    pillow
    psycopg
    pybars3
    pydantic
    pydantic-settings
    pyjwt
    python-dotenv
    python-frontmatter
    pyyaml
    rich
    sqlalchemy
    typer
    unidecode
    watchfiles
  ];

  pythonImportsCheck = [
    "basic_memory"
  ];

  meta = {
    description = "AI conversations that actually remember. Never re-explain your project to your AI again";
    homepage = "https://github.com/basicmachines-co/basic-memory";
    changelog = "https://github.com/basicmachines-co/basic-memory/blob/${src.rev}/CHANGELOG.md";
    license = lib.licenses.agpl3Only;
    maintainers = with lib.maintainers; [ ];
    mainProgram = "basic-memory";
  };
}
