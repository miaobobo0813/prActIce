import os
os.environ["HF_ENDPOINT"]="https://hf-mirror.com"

import json
from transformers import AutoModelForCausalLM, AutoTokenizer, Trainer, TrainingArguments, DataCollatorForLanguageModeling
from peft import LoraConfig, get_peft_model, TaskType
from datasets import Dataset

if __name__ == "__main__":
    MODELNAME = "Qwen/Qwen2.5-0.5B-Instruct"
    tokenizer = AutoTokenizer.from_pretrained(MODELNAME, trust_remote_code=True)
    if tokenizer.pad_token is None:
        tokenizer.pad_token = tokenizer.eos_token
    model = AutoModelForCausalLM.from_pretrained(MODELNAME, trust_remote_code=True, dtype="auto", device_map="cpu")

    def loadJson(filePath):
        with open(filePath, 'r', encoding='utf-8') as f:
            return json.load(f)

    dataOfQues = loadJson("./Sources/model/trainQuesData.json")
    dataOfGrade = loadJson("./Sources/model/trainGradeData.json")
    formattedDataOfQues = []
    for data in dataOfQues:
        messages = [
            {"role": "system", "content": "你是一个出卷老师，请按照科目、单元、年级、题型出题。题型的类型有choose, fillBlank, answer，分别对应选择/判断、填空、实验探究/解答/综合"}, 
            {"role": "user", "content": f"学科：{data['subject']}，年级：{data['grade'][1]}年级{"上册" if data['grade'][0] == 'A' else "下册"}，单元：{data['unit']}，题型：{data['type']}"}, 
            {"role": "assistant", "content": data['output']}
        ]
        inputID = tokenizer.apply_chat_template(messages, tokenize=True, generation_promat=False)
        formattedDataOfQues.append(inputID)
    datasetOfQues = Dataset.from_list(formattedDataOfQues)
    formattedDataOfGrade = []
    for data in dataOfGrade:
        output = "true" if data.get("output") else "false"
        messages = [
            {"role": "system", "content": "你是一个批改作业的老师，请用\"true\"和\"false\"批改。"}, 
            {"role": "user", "content": f"问题：{data['question']}，学生回答；{data['userAnswer']}"}, 
            {"role": "assistant", "content": output}
        ]
        inputID = tokenizer.apply_chat_template(messages, tokenize=True, generation_promat=False)
        formattedDataOfGrade.append(inputID)
    datasetOfGrade = Dataset.from_list(formattedDataOfGrade)
    peftConfig = LoraConfig(
        task_type=TaskType.CAUSAL_LM, 
        inference_mode=False, 
        r=8, 
        lora_alpha=32, 
        lora_dropout=0.1
    )
    model.add_adapter(peftConfig, adapter_name="ques")
    model.add_adapter(peftConfig, adapter_name="grade")

    model.set_adapter("ques")
    trainArgsForQues = TrainingArguments(
        output_dir="./Sources/model/outputQues", 
        num_train_epochs=3, 
        per_device_train_batch_size=1, 
        gradient_accumulation_steps=4, 
        learning_rate=2e-4, 
        fp16=False, 
        optim="adamw_torch", 
        logging_steps=1, 
        save_strategy="epoch", 
        dataloader_pin_memory=False, 
        dataloader_num_workers=0, 
        disable_tqdm=False
    )
    trainerForQues = Trainer(
        model=model, 
        args=trainArgsForQues, 
        train_dataset=datasetOfQues, 
        data_collator=DataCollatorForLanguageModeling(tokenizer, mlm=False)
    )
    trainerForQues.train()
    model.save_pretrained("./Sources/model/outputQues")

    model.set_adapter("grade")
    trainArgsForQues = TrainingArguments(
        output_dir="./Sources/model/outputGrade", 
        num_train_epochs=3, 
        per_device_train_batch_size=1, 
        gradient_accumulation_steps=4, 
        learning_rate=2e-4, 
        fp16=False, 
        optim="adamw_torch", 
        logging_steps=1, 
        save_strategy="epoch", 
        dataloader_pin_memory=False, 
        dataloader_num_workers=0, 
        disable_tqdm=False
    )
    trainerForQues = Trainer(
        model=model, 
        args=trainArgsForQues, 
        train_dataset=datasetOfQues, 
        data_collator=DataCollatorForLanguageModeling(tokenizer, mlm=False)
    )
    trainerForQues.train()
    model.save_pretrained("./Sources/model/outputGrade")