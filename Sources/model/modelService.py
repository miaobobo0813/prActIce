import os
import sys
from pathlib import Path

os.environ["HF_ENDPOINT"] = "https://hf-mirror.com"

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from transformers import AutoModelForCausalLM, AutoTokenizer
from peft import PeftModel
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


try:
    load_models()
except Exception:
    pass


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


@service.get("/ques")
async def quesAPI(grade: str, subject: str, unit: str, type: str):
    tokenizer, model = get_model_pair(is_grade_model=False)
    instruction = f"学科：{subject}，年级：{grade[1]}年级{'上册' if grade[0] == 'A' else '下册'}，单元：{unit}，题型：{type}"
    messages = [
        {
            "role": "system",
            "content": "你是一个出卷老师，请按照科目、单元、年级、题型出题。题型的类型中choose代表选择/判断, fillBlank代表填空, answer代表实验探究/解答/综合。只需出一题即可。",
        },
        {"role": "user", "content": instruction},
    ]
    try:
        text = tokenizer.apply_chat_template(messages, tokenize=False, generation_prompt=True)
        modelInputs = tokenizer([text], return_tensors="pt").to(model.device)
        generatedIDs = model.generate(**modelInputs, max_new_tokens=512)
        return {"text": decode_generated_text(tokenizer, modelInputs, generatedIDs)}
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"出题失败: {exc}") from exc


@service.get("/grade")
async def gradeAPI(ques: str, userAns: str):
    tokenizer, model = get_model_pair(is_grade_model=True)
    instruction = f"问题：{ques}，学生回答：{userAns}"
    messages = [
        {"role": "system", "content": "你是一个批改作业的老师，请用\"true\"和\"false\"批改。"},
        {"role": "user", "content": instruction},
    ]
    try:
        text = tokenizer.apply_chat_template(messages, tokenize=False, generation_prompt=True)
        modelInputs = tokenizer([text], return_tensors="pt").to(model.device)
        generatedIDs = model.generate(**modelInputs, max_new_tokens=512)
        return {"text": decode_generated_text(tokenizer, modelInputs, generatedIDs)}
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"批改失败: {exc}") from exc


@service.get("/test")
def testAPI():
    return {"text": True}


if __name__ == "__main__":
    uvicorn.run(service, host="127.0.0.1", port=8000)