import os
import re
import sys
from pathlib import Path

os.environ["HF_ENDPOINT"] = "https://hf-mirror.com"

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from transformers import AutoModelForCausalLM, AutoTokenizer
from peft import PeftModel
from pydantic import BaseModel
import uvicorn


def resolve_model_path(path_candidate: str | None, default_name: str) -> str:
    if path_candidate:
        candidate = Path(path_candidate).expanduser()
        if candidate.exists():
            return str(candidate.resolve())

    fallback = (Path(__file__).resolve().parent / default_name).resolve()
    if fallback.exists():
        return str(fallback)

    return str(Path(path_candidate or default_name).expanduser().resolve())


outputQuesPath = resolve_model_path(sys.argv[1] if len(sys.argv) > 1 else None, "outputQues")
outputGradePath = resolve_model_path(sys.argv[2] if len(sys.argv) > 2 else None, "outputGrade")

service = FastAPI(title="Model Adapter Service for prActIce")
service.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_headers=["*"],
    allow_methods=["*"],
)
MODELNAME = "Qwen/Qwen2.5-0.5B-Instruct"

startup_error: str | None = None
tokenizerForQues = None
modelForQues = None
tokenizerForGrade = None
modelForGrade = None


class QuestionRequest(BaseModel):
    grade: str
    subject: str
    unit: str
    type: str
    scope: str


class GradeRequest(BaseModel):
    ques: str
    userAns: str


def load_models() -> None:
    global startup_error, tokenizerForQues, modelForQues, tokenizerForGrade, modelForGrade

    try:
        tokenizerForQues = AutoTokenizer.from_pretrained(MODELNAME, trust_remote_code=True)
        baseModelForQues = AutoModelForCausalLM.from_pretrained(
            MODELNAME,
            dtype="auto",
            trust_remote_code=True,
            device_map="cpu",
        )
        modelForQues = PeftModel.from_pretrained(baseModelForQues, outputQuesPath)
        modelForQues.eval()

        tokenizerForGrade = AutoTokenizer.from_pretrained(MODELNAME, trust_remote_code=True)
        baseModelForGrade = AutoModelForCausalLM.from_pretrained(
            MODELNAME,
            dtype="auto",
            trust_remote_code=True,
            device_map="cpu",
        )
        modelForGrade = PeftModel.from_pretrained(baseModelForGrade, outputGradePath)
        modelForGrade.eval()
        startup_error = None
    except Exception as exc: 
        startup_error = f"模型加载失败: {exc}"
        raise

load_models()

def get_model_pair(is_grade_model: bool):
    if is_grade_model:
        if tokenizerForGrade is None or modelForGrade is None:
            raise HTTPException(status_code=503, detail=startup_error or "评分模型暂不可用")
        return tokenizerForGrade, modelForGrade

    if tokenizerForQues is None or modelForQues is None:
        raise HTTPException(status_code=503, detail=startup_error or "出题模型暂不可用")
    return tokenizerForQues, modelForQues


def decode_generated_text(tokenizer, model_inputs, generated_ids) -> str:
    input_length = model_inputs.input_ids.shape[1]
    return tokenizer.decode(generated_ids[0, input_length:], skip_special_tokens=True).strip()


def normalize_grade_output(raw_text: str) -> str:
    text = raw_text.strip()
    match = re.search(r"(\d+)\s*/\s*(\d+)", text)
    if match:
        earned = int(match.group(1))
        total = int(match.group(2))
        return f"{earned}/{total}"
    if re.search(r"\btrue\b|\b正确\b|\b对\b", text, re.IGNORECASE):
        return "1/1"
    if re.search(r"\bfalse\b|\b错误\b|\b错\b", text, re.IGNORECASE):
        return "0/1"
    return "0/1"


@service.post("/ques")
async def quesAPI(request: QuestionRequest):
    tokenizer, model = get_model_pair(is_grade_model=False)
    instruction = f"学科：{request.subject}，年级：{request.grade[1]}年级{'上册' if request.grade[0] == 'A' else '下册'}，单元：{request.unit}，题型：{request.type}，范围：{request.scope}"
    messages = [
        {
            "role": "system",
            "content": "你是一个出卷老师，请按照科目、单元、年级、题型出题。choose代表选择/判断, fillBlank代表填空, answer代表实验探究/解答/综合。数学、科学使用浙教版，英语使用外研版，剩余科目使用人教版。只需出一题即可。不需要给出答案。",
        },
        {"role": "user", "content": instruction},
    ]
    try:
        text = tokenizer.apply_chat_template(messages, tokenize=False, generation_prompt=True)
        modelInputs = tokenizer([text], return_tensors="pt").to(model.device)
        generatedIDs = model.generate(**modelInputs, max_new_tokens=1024)
        return {"text": decode_generated_text(tokenizer, modelInputs, generatedIDs)}
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"出题失败: {exc}") from exc


@service.post("/grade")
async def gradeAPI(request: GradeRequest):
    tokenizer, model = get_model_pair(is_grade_model=True)
    instruction = f"问题：{request.ques}，学生回答：{request.userAns}"
    messages = [
        {
            "role": "system",
            "content": "你是一个批改作业的老师。请根据题目类型进行评分：选择题和填空题每空1分，若回答正确则输出 1/1；若回答错误则输出 0/1；若题目包含多个空，请按空数给出如 2/3 或 1/3 的分数。请只输出最终评分结果，不要解释。",
        },
        {"role": "user", "content": instruction},
    ]
    try:
        text = tokenizer.apply_chat_template(messages, tokenize=False, generation_prompt=True)
        modelInputs = tokenizer([text], return_tensors="pt").to(model.device)
        generatedIDs = model.generate(**modelInputs, max_new_tokens=1024)
        raw_text = decode_generated_text(tokenizer, modelInputs, generatedIDs)
        return {"text": normalize_grade_output(raw_text)}
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"批改失败: {exc}") from exc


@service.get("/test")
def testAPI():
    return {"text": True}


if __name__ == "__main__":
    uvicorn.run(service, host="127.0.0.1", port=8000)